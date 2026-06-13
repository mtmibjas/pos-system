// Package api round-trip tests. Each test boots a real local-store-server
// stack (in-memory SQLite + opslog + sales + refunds + tax) behind an
// httptest server, then drives it through the generated Connect clients.
// The point is to prove the wire contract works end-to-end: codegen
// agrees with handlers, handlers agree with the domain services, and
// typed domain errors land back at the client as the right connect.Code.
package api_test

import (
	"context"
	"net/http/httptest"
	"path/filepath"
	"testing"
	"time"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	"github.com/stretchr/testify/require"
	"google.golang.org/protobuf/types/known/timestamppb"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/api"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/refunds"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

const (
	testTenant = "tenant-A"
	testStore  = "store-1"
	testNode   = "node-api-test"
)

// testServer bundles the boot stack plus the running httptest server and
// pre-built Connect clients, so individual tests stay readable.
type testServer struct {
	url       string
	saleCli   posv1connect.SaleServiceClient
	refundCli posv1connect.RefundServiceClient
	taxCli    posv1connect.TaxAdminServiceClient
	itemCli   posv1connect.ItemServiceClient
	invCli    posv1connect.InventoryServiceClient
	resvCli   posv1connect.ReservationServiceClient

	inv    *inventory.Store         // exposed for stock seeding
	pays   *payments.Store          // exposed for balance assertions
	hub    *hub.Hub                 // exposed for realtime fan-out tests (slice 4.2)
	events *api.EventsStreamHandler // exposed for slice 4.4 reconnect tuning
}

// overrideMaxReplay tweaks the live WS handler's per-reconnect replay cap.
// Tests for slice 4.4's overflow path call this to keep the test backlog
// small. Safe to call after newTestServer because httptest.Server hands
// the request to the same *EventsStreamHandler instance we constructed.
func (s *testServer) overrideMaxReplay(n int) { s.events.MaxReplay = n }

func newTestServer(t *testing.T) *testServer {
	t.Helper()
	ctx := context.Background()

	path := filepath.Join(t.TempDir(), "api.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))

	state := syncstate.NewStore(sqlDB)
	clk, err := clock.New(ctx, state)
	require.NoError(t, err)

	ops := opslog.NewStore(sqlDB)
	inv := inventory.NewStore(sqlDB, nil)
	pays := payments.NewStore(sqlDB)
	invs := invoices.NewStore(sqlDB, time.UTC)
	taxStore := tax.NewStore(sqlDB)
	taxEng := tax.NewEngine(taxStore)
	itemStore := items.NewStore(sqlDB, taxStore)
	refStore := refunds.NewStore(sqlDB, time.UTC)

	eventHub := hub.New()

	reservationStore := reservations.NewStore(sqlDB)
	reservationSvc, err := reservations.NewService(reservations.Config{
		DB: sqlDB, Store: reservationStore, Inv: inv, Publisher: eventHub,
	})
	require.NoError(t, err)

	saleSvc, err := sales.NewService(sales.Config{
		DB: sqlDB, Ops: ops, Inv: inv, Pays: pays, Invoices: invs,
		Tax: taxEng, Clock: clk, Notifier: sales.NoopNotifier{},
		Publisher:    eventHub,
		Reservations: reservationSvc,
		NodeID:       testNode, TenantID: testTenant,
	})
	require.NoError(t, err)

	refundSvc, err := refunds.NewService(refunds.Config{
		DB: sqlDB, Ops: ops, Inv: inv, Pays: pays, Invoices: invs,
		Refunds: refStore, Tax: taxEng, Clock: clk, Notifier: refunds.NoopNotifier{},
		Publisher: eventHub,
		NodeID:    testNode, TenantID: testTenant,
		VoidWindow: 12 * time.Hour,
	})
	require.NoError(t, err)

	eventsHandler := api.NewEventsStreamHandler(eventHub, ops, nil)
	mux := api.NewMux(
		api.NewSaleHandler(saleSvc, invs, pays),
		api.NewRefundHandler(refundSvc),
		api.NewTaxAdminHandler(taxStore, testTenant),
		api.NewItemHandler(itemStore, testTenant),
		api.NewInventoryHandler(inv, itemStore, testTenant),
		api.NewReservationHandler(reservationSvc),
		eventsHandler,
	)
	srv := httptest.NewServer(api.H2CHandler(mux))
	t.Cleanup(srv.Close)

	return &testServer{
		url:       srv.URL,
		saleCli:   posv1connect.NewSaleServiceClient(srv.Client(), srv.URL),
		refundCli: posv1connect.NewRefundServiceClient(srv.Client(), srv.URL),
		taxCli:    posv1connect.NewTaxAdminServiceClient(srv.Client(), srv.URL),
		itemCli:   posv1connect.NewItemServiceClient(srv.Client(), srv.URL),
		invCli:    posv1connect.NewInventoryServiceClient(srv.Client(), srv.URL),
		resvCli:   posv1connect.NewReservationServiceClient(srv.Client(), srv.URL),
		inv:    inv,
		pays:   pays,
		hub:    eventHub,
		events: eventsHandler,
	}
}

// seedStock receives qty into testStore for sku via the inventory ledger
// directly — bypasses the API so tests can prepare state cheaply.
func (s *testServer) seedStock(t *testing.T, sku string, qty int64) {
	t.Helper()
	require.NoError(t, s.inv.Append(context.Background(), inventory.Movement{
		MovementID:   uuid.New(),
		SKU:          sku,
		StoreID:      testStore,
		Delta:        qty,
		Reason:       inventory.ReasonReceive,
		RefType:      "receive",
		RefID:        "seed",
		OccurredAt:   time.Now().UTC(),
		Lamport:      0,
		OriginNodeID: "seed",
	}))
}

// --- SaleService.Finalize -----------------------------------------------

func TestSaleService_Finalize_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-A", 5)

	now := time.Now().UTC()
	saleID := uuid.New()
	lineID := uuid.New()
	payID := uuid.New()

	resp, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    lineID.String(),
			Sku:       "SKU-A",
			Quantity:  2,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: payID.String(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		OccurredAt: timestamppb.New(now),
	}))
	require.NoError(t, err)
	require.Equal(t, saleID.String(), resp.Msg.GetSaleId())
	require.False(t, resp.Msg.GetIdempotent())
	require.NotEmpty(t, resp.Msg.GetInvoice().GetInvoiceNumber())
	require.Equal(t, int64(10), resp.Msg.GetInvoice().GetGrandTotal().GetUnits())

	// Underlying stock is decremented and balance matches.
	stock, err := srv.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.NoError(t, err)
	require.Equal(t, int64(3), stock)
	bal, err := srv.pays.Balance(context.Background(), saleID)
	require.NoError(t, err)
	require.Equal(t, int64(10), bal.Units)
}

func TestSaleService_Finalize_Idempotent(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-A", 5)

	now := time.Now().UTC()
	saleID := uuid.New()
	req := &posv1.FinalizeRequest{
		SaleId:  saleID.String(),
		StoreId: &posv1.StoreId{Value: testStore},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    uuid.NewString(),
			Sku:       "SKU-A",
			Quantity:  1,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		OccurredAt: timestamppb.New(now),
	}
	first, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(req))
	require.NoError(t, err)
	require.False(t, first.Msg.GetIdempotent())

	second, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(req))
	require.NoError(t, err)
	require.True(t, second.Msg.GetIdempotent())
	require.Equal(t, first.Msg.GetInvoice().GetInvoiceNumber(),
		second.Msg.GetInvoice().GetInvoiceNumber())
}

func TestSaleService_Finalize_BadSaleID_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:     "not-a-uuid",
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

func TestSaleService_Finalize_TenderSumMismatch_FailedPrecondition(t *testing.T) {
	srv := newTestServer(t)
	srv.seedStock(t, "SKU-A", 5)
	saleID := uuid.New()
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:  saleID.String(),
		StoreId: &posv1.StoreId{Value: testStore},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    uuid.NewString(),
			Sku:       "SKU-A",
			Quantity:  1,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: uuid.NewString(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 3}, // doesn't cover the sale
		}},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
}

// --- RefundService -------------------------------------------------------

// helper: finalize a 2 × $5 cash sale via the API and return its ids.
func finalizeSeed(t *testing.T, srv *testServer, at time.Time) (saleID, lineID, payID uuid.UUID) {
	t.Helper()
	srv.seedStock(t, "SKU-A", 10)
	saleID = uuid.New()
	lineID = uuid.New()
	payID = uuid.New()
	_, err := srv.saleCli.Finalize(context.Background(), connect.NewRequest(&posv1.FinalizeRequest{
		SaleId:    saleID.String(),
		StoreId:   &posv1.StoreId{Value: testStore},
		CounterId: &posv1.CounterId{Value: "counter-1"},
		Lines: []*posv1.FinalizeSaleLine{{
			LineId:    lineID.String(),
			Sku:       "SKU-A",
			Quantity:  2,
			UnitPrice: &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal: &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		Tenders: []*posv1.FinalizeSaleTender{{
			PaymentId: payID.String(),
			Method:    string(payments.MethodCash),
			Amount:    &posv1.Money{CurrencyCode: "USD", Units: 10},
		}},
		OccurredAt: timestamppb.New(at),
	}))
	require.NoError(t, err)
	return
}

func TestRefundService_VoidSale_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, _, _ := finalizeSeed(t, srv, now)

	resp, err := srv.refundCli.VoidSale(context.Background(), connect.NewRequest(&posv1.VoidSaleRequest{
		VoidId:     uuid.NewString(),
		SaleId:     saleID.String(),
		StoreId:    &posv1.StoreId{Value: testStore},
		Reason:     "wrong sale",
		OccurredAt: timestamppb.New(now.Add(time.Minute)),
	}))
	require.NoError(t, err)
	require.Equal(t, saleID.String(), resp.Msg.GetVoid().GetSaleId())

	// Stock fully restored.
	stock, _ := srv.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.Equal(t, int64(10), stock)
	// Payment balance back to zero.
	bal, _ := srv.pays.Balance(context.Background(), saleID)
	require.True(t, bal.IsZero())
}

func TestRefundService_VoidSale_OutsideWindow_FailedPrecondition(t *testing.T) {
	srv := newTestServer(t)
	// Sale 24h ago; void window default is 12h.
	old := time.Now().UTC().Add(-24 * time.Hour)
	saleID, _, _ := finalizeSeed(t, srv, old)

	_, err := srv.refundCli.VoidSale(context.Background(), connect.NewRequest(&posv1.VoidSaleRequest{
		VoidId:     uuid.NewString(),
		SaleId:     saleID.String(),
		StoreId:    &posv1.StoreId{Value: testStore},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
}

func TestRefundService_RefundSale_Partial_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, lineID, payID := finalizeSeed(t, srv, now)

	resp, err := srv.refundCli.RefundSale(context.Background(), connect.NewRequest(&posv1.RefundSaleRequest{
		RefundId:   uuid.NewString(),
		SaleId:     saleID.String(),
		StoreId:    &posv1.StoreId{Value: testStore},
		OccurredAt: timestamppb.New(now.Add(time.Hour)),
		Reason:     "damaged",
		Lines: []*posv1.RefundSaleLine{{
			SaleLineId: lineID.String(),
			Sku:        "SKU-A",
			Quantity:   1,
			Restock:    true,
			UnitPrice:  &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal:  &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		Tenders: []*posv1.RefundSaleTender{{
			RefundPaymentId:   uuid.NewString(),
			OriginalPaymentId: payID.String(),
			Method:            string(payments.MethodCash),
			Amount:            &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
	}))
	require.NoError(t, err)
	require.NotEmpty(t, resp.Msg.GetRefund().GetCreditNoteNumber())

	// One unit restocked: 10 (seed) - 2 (sold) + 1 (refunded restock) = 9.
	stock, _ := srv.inv.StockOnHand(context.Background(), testStore, "SKU-A")
	require.Equal(t, int64(9), stock)
}

func TestRefundService_RefundSale_OverRefund_FailedPrecondition(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, lineID, payID := finalizeSeed(t, srv, now)

	// Try to refund 3 units of a 2-unit sale.
	_, err := srv.refundCli.RefundSale(context.Background(), connect.NewRequest(&posv1.RefundSaleRequest{
		RefundId:   uuid.NewString(),
		SaleId:     saleID.String(),
		StoreId:    &posv1.StoreId{Value: testStore},
		OccurredAt: timestamppb.New(now.Add(time.Hour)),
		Lines: []*posv1.RefundSaleLine{{
			SaleLineId: lineID.String(),
			Sku:        "SKU-A",
			Quantity:   3,
			UnitPrice:  &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal:  &posv1.Money{CurrencyCode: "USD", Units: 15},
		}},
		Tenders: []*posv1.RefundSaleTender{{
			RefundPaymentId:   uuid.NewString(),
			OriginalPaymentId: payID.String(),
			Method:            string(payments.MethodCash),
			Amount:            &posv1.Money{CurrencyCode: "USD", Units: 15},
		}},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeFailedPrecondition, connect.CodeOf(err))
}

func TestRefundService_RefundSale_BadRefundID_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.refundCli.RefundSale(context.Background(), connect.NewRequest(&posv1.RefundSaleRequest{
		RefundId:   "garbage",
		SaleId:     uuid.NewString(),
		StoreId:    &posv1.StoreId{Value: testStore},
		OccurredAt: timestamppb.New(time.Now().UTC()),
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

// --- TaxAdminService -----------------------------------------------------

func TestTaxAdminService_UpsertAndGet(t *testing.T) {
	srv := newTestServer(t)
	ctx := context.Background()

	_, err := srv.taxCli.UpsertTaxCategory(ctx, connect.NewRequest(&posv1.UpsertTaxCategoryRequest{
		Category: &posv1.TaxCategory{
			Id:               "GST-18",
			Name:             "GST 18%",
			PriceIncludesTax: false,
		},
	}))
	require.NoError(t, err)

	_, err = srv.taxCli.UpsertTaxComponent(ctx, connect.NewRequest(&posv1.UpsertTaxComponentRequest{
		Component: &posv1.TaxComponent{
			Id:              "CGST-9",
			TaxCategoryId:   "GST-18",
			Name:            "CGST 9%",
			RateBasisPoints: 900,
			SortOrder:       1,
		},
	}))
	require.NoError(t, err)

	got, err := srv.taxCli.GetTaxCategory(ctx, connect.NewRequest(&posv1.GetTaxCategoryRequest{
		Id: "GST-18",
	}))
	require.NoError(t, err)
	require.Equal(t, "GST 18%", got.Msg.GetCategory().GetName())
	require.Equal(t, testTenant, got.Msg.GetCategory().GetTenantId(),
		"server should pin tenant from config, not echo client input")
	require.Len(t, got.Msg.GetCategory().GetComponents(), 1)
	require.Equal(t, int32(900), got.Msg.GetCategory().GetComponents()[0].GetRateBasisPoints())
}

func TestTaxAdminService_GetUnknown_NotFound(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.taxCli.GetTaxCategory(context.Background(), connect.NewRequest(&posv1.GetTaxCategoryRequest{
		Id: "does-not-exist",
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeNotFound, connect.CodeOf(err))
}

func TestTaxAdminService_UpsertNilCategory_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.taxCli.UpsertTaxCategory(context.Background(), connect.NewRequest(&posv1.UpsertTaxCategoryRequest{
		Category: nil,
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

// --- ItemService round-trips ---

func upsertGST18(t *testing.T, srv *testServer) {
	t.Helper()
	_, err := srv.taxCli.UpsertTaxCategory(context.Background(), connect.NewRequest(&posv1.UpsertTaxCategoryRequest{
		Category: &posv1.TaxCategory{Id: "GST-18", Name: "GST 18%"},
	}))
	require.NoError(t, err)
}

func TestItemService_UpsertGetList_RoundTrip(t *testing.T) {
	ctx := context.Background()
	srv := newTestServer(t)
	upsertGST18(t, srv)

	_, err := srv.itemCli.UpsertItem(ctx, connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			Sku:           "BREAD-WW",
			Name:          "Whole Wheat Bread",
			Price:         &posv1.Money{CurrencyCode: "INR", Units: 60},
			TaxCategoryId: "GST-18",
		},
	}))
	require.NoError(t, err)

	got, err := srv.itemCli.GetItem(ctx, connect.NewRequest(&posv1.GetItemRequest{Sku: "BREAD-WW"}))
	require.NoError(t, err)
	require.Equal(t, "BREAD-WW", got.Msg.GetItem().GetSku())
	require.Equal(t, testTenant, got.Msg.GetItem().GetTenantId(),
		"server should pin tenant, not echo client input")
	require.Equal(t, "Whole Wheat Bread", got.Msg.GetItem().GetName())
	require.Equal(t, int64(60), got.Msg.GetItem().GetPrice().GetUnits())
	require.False(t, got.Msg.GetItem().GetArchived())

	// Second item to verify ordering.
	_, err = srv.itemCli.UpsertItem(ctx, connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			Sku:   "APPLE-1KG",
			Name:  "Apples 1kg",
			Price: &posv1.Money{CurrencyCode: "INR", Units: 200},
		},
	}))
	require.NoError(t, err)

	list, err := srv.itemCli.ListItems(ctx, connect.NewRequest(&posv1.ListItemsRequest{}))
	require.NoError(t, err)
	require.Len(t, list.Msg.GetItems(), 2)
	require.Equal(t, "APPLE-1KG", list.Msg.GetItems()[0].GetSku(),
		"ListItems must order by SKU ASC")
	require.Equal(t, "BREAD-WW", list.Msg.GetItems()[1].GetSku())
}

func TestItemService_GetUnknown_NotFound(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.itemCli.GetItem(context.Background(), connect.NewRequest(&posv1.GetItemRequest{
		Sku: "GHOST",
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeNotFound, connect.CodeOf(err))
}

func TestItemService_UpsertNilItem_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.itemCli.UpsertItem(context.Background(), connect.NewRequest(&posv1.UpsertItemRequest{
		Item: nil,
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

func TestItemService_UpsertMissingFields_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.itemCli.UpsertItem(context.Background(), connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			// SKU missing
			Name:  "X",
			Price: &posv1.Money{CurrencyCode: "INR", Units: 1},
		},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

func TestItemService_UpsertUnknownTaxCategory_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	// Note: NOT seeding the tax category — so the FK pre-check fails.
	_, err := srv.itemCli.UpsertItem(context.Background(), connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			Sku:           "X",
			Name:          "X",
			Price:         &posv1.Money{CurrencyCode: "INR", Units: 1},
			TaxCategoryId: "DOES-NOT-EXIST",
		},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

func TestItemService_ListIncludeArchived(t *testing.T) {
	ctx := context.Background()
	srv := newTestServer(t)
	upsertGST18(t, srv)

	for _, sku := range []string{"A", "B"} {
		_, err := srv.itemCli.UpsertItem(ctx, connect.NewRequest(&posv1.UpsertItemRequest{
			Item: &posv1.Item{
				Sku: sku, Name: sku,
				Price: &posv1.Money{CurrencyCode: "INR", Units: 10},
			},
		}))
		require.NoError(t, err)
	}
	// Archive B.
	_, err := srv.itemCli.UpsertItem(ctx, connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			Sku: "B", Name: "B",
			Price:    &posv1.Money{CurrencyCode: "INR", Units: 10},
			Archived: true,
		},
	}))
	require.NoError(t, err)

	live, err := srv.itemCli.ListItems(ctx, connect.NewRequest(&posv1.ListItemsRequest{}))
	require.NoError(t, err)
	require.Len(t, live.Msg.GetItems(), 1)
	require.Equal(t, "A", live.Msg.GetItems()[0].GetSku())

	all, err := srv.itemCli.ListItems(ctx, connect.NewRequest(&posv1.ListItemsRequest{IncludeArchived: true}))
	require.NoError(t, err)
	require.Len(t, all.Msg.GetItems(), 2)
	require.True(t, all.Msg.GetItems()[1].GetArchived())
}

// --- SaleService.GetSale -------------------------------------------------

func TestSaleService_GetSale_BySaleID_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, lineID, payID := finalizeSeed(t, srv, now)

	resp, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_SaleId{SaleId: saleID.String()},
	}))
	require.NoError(t, err)
	require.Equal(t, saleID.String(), resp.Msg.GetInvoice().GetSaleId())
	require.NotEmpty(t, resp.Msg.GetInvoice().GetInvoiceNumber())

	require.Len(t, resp.Msg.GetLines(), 1)
	gotLine := resp.Msg.GetLines()[0]
	require.Equal(t, lineID.String(), gotLine.GetLineId())
	require.Equal(t, "SKU-A", gotLine.GetSku())
	require.Equal(t, int64(2), gotLine.GetQuantity())
	require.Equal(t, int64(10), gotLine.GetLineTotal().GetUnits())

	require.Len(t, resp.Msg.GetPayments(), 1)
	gotPay := resp.Msg.GetPayments()[0]
	require.Equal(t, payID.String(), gotPay.GetPaymentId())
	require.Equal(t, string(payments.MethodCash), gotPay.GetMethod())
	require.Equal(t, int64(10), gotPay.GetAmount().GetUnits())
}

func TestSaleService_GetSale_ByInvoiceNumber_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, _, _ := finalizeSeed(t, srv, now)

	// Fetch the invoice number via sale_id first.
	bySale, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_SaleId{SaleId: saleID.String()},
	}))
	require.NoError(t, err)
	invNum := bySale.Msg.GetInvoice().GetInvoiceNumber()
	require.NotEmpty(t, invNum)

	byNum, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_InvoiceNumber{InvoiceNumber: invNum},
	}))
	require.NoError(t, err)
	require.Equal(t, saleID.String(), byNum.Msg.GetInvoice().GetSaleId())
	require.Equal(t, invNum, byNum.Msg.GetInvoice().GetInvoiceNumber())
}

func TestSaleService_GetSale_NotFound(t *testing.T) {
	srv := newTestServer(t)

	_, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_SaleId{SaleId: uuid.NewString()},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeNotFound, connect.CodeOf(err))

	_, err = srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_InvoiceNumber{InvoiceNumber: "INV-1999-000001"},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeNotFound, connect.CodeOf(err))
}

func TestSaleService_GetSale_MissingKey_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)

	_, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))

	_, err = srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_SaleId{SaleId: "not-a-uuid"},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))

	_, err = srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_InvoiceNumber{InvoiceNumber: ""},
	}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

// --- InventoryService.ListOnHand ----------------------------------------

func TestInventoryService_ListOnHand_HappyPath(t *testing.T) {
	srv := newTestServer(t)
	// Seed catalog so the row joins to a name + price.
	ctx := context.Background()
	_, err := srv.itemCli.UpsertItem(ctx, connect.NewRequest(&posv1.UpsertItemRequest{
		Item: &posv1.Item{
			Sku:   "SKU-A",
			Name:  "Apples",
			Price: &posv1.Money{CurrencyCode: "INR", Units: 10},
		},
	}))
	require.NoError(t, err)
	srv.seedStock(t, "SKU-A", 7)

	// SKU with movements but no catalog row — should render with empty name.
	srv.seedStock(t, "SKU-ORPHAN", 3)

	resp, err := srv.invCli.ListOnHand(ctx, connect.NewRequest(&posv1.ListOnHandRequest{
		StoreId: &posv1.StoreId{Value: testStore},
	}))
	require.NoError(t, err)
	rows := resp.Msg.GetRows()
	require.Len(t, rows, 2)

	// Sorted by SKU asc → SKU-A before SKU-ORPHAN.
	require.Equal(t, "SKU-A", rows[0].GetSku())
	require.Equal(t, "Apples", rows[0].GetName())
	require.Equal(t, int64(10), rows[0].GetPrice().GetUnits())
	require.Equal(t, int64(7), rows[0].GetOnHand())

	require.Equal(t, "SKU-ORPHAN", rows[1].GetSku())
	require.Empty(t, rows[1].GetName())
	require.Equal(t, int64(3), rows[1].GetOnHand())
}

func TestInventoryService_ListOnHand_MissingStoreID_InvalidArgument(t *testing.T) {
	srv := newTestServer(t)
	_, err := srv.invCli.ListOnHand(context.Background(), connect.NewRequest(&posv1.ListOnHandRequest{}))
	require.Error(t, err)
	require.Equal(t, connect.CodeInvalidArgument, connect.CodeOf(err))
}

func TestInventoryService_ListOnHand_EmptyStore(t *testing.T) {
	srv := newTestServer(t)
	resp, err := srv.invCli.ListOnHand(context.Background(), connect.NewRequest(&posv1.ListOnHandRequest{
		StoreId: &posv1.StoreId{Value: testStore},
	}))
	require.NoError(t, err)
	require.Empty(t, resp.Msg.GetRows())
}

func TestSaleService_GetSale_AfterRefund_OnlyOriginalTenders(t *testing.T) {
	srv := newTestServer(t)
	now := time.Now().UTC()
	saleID, lineID, payID := finalizeSeed(t, srv, now)

	// Issue a partial refund — should add a refund-side payment row that
	// GetSale must filter out.
	_, err := srv.refundCli.RefundSale(context.Background(), connect.NewRequest(&posv1.RefundSaleRequest{
		RefundId: uuid.NewString(),
		SaleId:   saleID.String(),
		StoreId:  &posv1.StoreId{Value: testStore},
		Lines: []*posv1.RefundSaleLine{{
			SaleLineId: lineID.String(),
			Sku:        "SKU-A",
			Quantity:   1,
			Restock:    true,
			UnitPrice:  &posv1.Money{CurrencyCode: "USD", Units: 5},
			LineTotal:  &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		Tenders: []*posv1.RefundSaleTender{{
			RefundPaymentId:   uuid.NewString(),
			OriginalPaymentId: payID.String(),
			Method:            string(payments.MethodCash),
			Amount:            &posv1.Money{CurrencyCode: "USD", Units: 5},
		}},
		OccurredAt: timestamppb.New(now.Add(time.Minute)),
	}))
	require.NoError(t, err)

	resp, err := srv.saleCli.GetSale(context.Background(), connect.NewRequest(&posv1.GetSaleRequest{
		Key: &posv1.GetSaleRequest_SaleId{SaleId: saleID.String()},
	}))
	require.NoError(t, err)
	require.Len(t, resp.Msg.GetPayments(), 1, "refund tender should be filtered out")
	require.Equal(t, payID.String(), resp.Msg.GetPayments()[0].GetPaymentId())
}
