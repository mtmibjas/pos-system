package api

import (
	"context"
	"errors"
	"fmt"

	"connectrpc.com/connect"
	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// SaleHandler adapts sales.Service to posv1connect.SaleServiceHandler.
//
// The handler also fronts the read-side GetSale RPC, which composes the
// invoices.Store (lookup by sale_id or invoice_number) with the
// payments.Store (per-sale tender list). Lines come straight from the
// canonical SaleCreated snapshot stored on the invoice — same bytes the
// cloud sees, so refund flows can rely on the line_ids matching.
type SaleHandler struct {
	posv1connect.UnimplementedSaleServiceHandler
	svc      *sales.Service
	invoices *invoices.Store
	payments *payments.Store
}

// NewSaleHandler wraps a non-nil sales.Service plus the read-side stores
// it needs for GetSale.
func NewSaleHandler(svc *sales.Service, invs *invoices.Store, pays *payments.Store) *SaleHandler {
	if svc == nil {
		panic("api: NewSaleHandler requires a non-nil *sales.Service")
	}
	if invs == nil {
		panic("api: NewSaleHandler requires a non-nil *invoices.Store")
	}
	if pays == nil {
		panic("api: NewSaleHandler requires a non-nil *payments.Store")
	}
	return &SaleHandler{svc: svc, invoices: invs, payments: pays}
}

// Finalize translates the wire request, invokes sales.Service.Finalize,
// and translates the response (or error). The wire tenant_id is ignored —
// tenant is pinned at server construction (see sale_service.proto).
func (h *SaleHandler) Finalize(
	ctx context.Context,
	req *connect.Request[posv1.FinalizeRequest],
) (*connect.Response[posv1.FinalizeResponse], error) {
	in := req.Msg

	saleID, err := uuid.Parse(in.GetSaleId())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("sale_id: %w", err))
	}

	lines, err := saleLinesFromProto(in.GetLines())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	tenders, err := saleTendersFromProto(in.GetTenders())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	reservationIDs, err := parseReservationIDs(in.GetReservationIds())
	if err != nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, err)
	}

	domainReq := sales.FinalizeRequest{
		SaleID:         saleID,
		StoreID:        storeIDValue(in.GetStoreId()),
		CounterID:      counterIDValue(in.GetCounterId()),
		CashierID:      userIDValue(in.GetCashierId()),
		Lines:          lines,
		Tenders:        tenders,
		Subtotal:       moneyFromProto(in.GetSubtotal()),
		TaxTotal:       moneyFromProto(in.GetTaxTotal()),
		GrandTotal:     moneyFromProto(in.GetGrandTotal()),
		OccurredAt:     timeFromProto(in.GetOccurredAt()),
		ReservationIDs: reservationIDs,
	}

	out, err := h.svc.Finalize(ctx, domainReq)
	if err != nil {
		return nil, toConnectErr(err)
	}

	return connect.NewResponse(&posv1.FinalizeResponse{
		SaleId:     out.SaleID.String(),
		BatchId:    out.BatchID.String(),
		Lamport:    out.Lamport,
		Invoice:    invoiceToProto(out.Invoice),
		Idempotent: out.Idempotent,
	}), nil
}

// GetSale resolves an invoice by sale_id or invoice_number (oneof), then
// decodes the SaleCreated snapshot for per-line detail and joins payments
// for tender detail. Refund tenders (negative amounts / parent_payment_id
// set) are filtered out — callers want the original tenders that produced
// the sale, not the reversal history.
func (h *SaleHandler) GetSale(
	ctx context.Context,
	req *connect.Request[posv1.GetSaleRequest],
) (*connect.Response[posv1.GetSaleResponse], error) {
	in := req.Msg

	var (
		inv    invoices.Invoice
		err    error
		lookup string
	)
	switch k := in.GetKey().(type) {
	case *posv1.GetSaleRequest_SaleId:
		lookup = "sale_id"
		var saleID uuid.UUID
		saleID, err = uuid.Parse(k.SaleId)
		if err != nil {
			return nil, connect.NewError(connect.CodeInvalidArgument,
				fmt.Errorf("sale_id: %w", err))
		}
		inv, err = h.invoices.GetBySale(ctx, saleID)
	case *posv1.GetSaleRequest_InvoiceNumber:
		lookup = "invoice_number"
		if k.InvoiceNumber == "" {
			return nil, connect.NewError(connect.CodeInvalidArgument,
				errors.New("invoice_number: empty"))
		}
		inv, err = h.invoices.GetByInvoiceNumber(ctx, k.InvoiceNumber)
	case nil:
		return nil, connect.NewError(connect.CodeInvalidArgument,
			errors.New("key: oneof not set"))
	default:
		return nil, connect.NewError(connect.CodeInvalidArgument,
			fmt.Errorf("key: unknown variant %T", k))
	}
	if errors.Is(err, invoices.ErrNotFound) {
		return nil, connect.NewError(connect.CodeNotFound,
			fmt.Errorf("sale not found by %s", lookup))
	}
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal,
			fmt.Errorf("invoices: lookup: %w", err))
	}

	var snap posv1.SaleCreated
	if err := proto.Unmarshal(inv.Snapshot, &snap); err != nil {
		return nil, connect.NewError(connect.CodeInternal,
			fmt.Errorf("snapshot: unmarshal: %w", err))
	}

	pays, err := h.payments.ListForSale(ctx, inv.SaleID)
	if err != nil {
		return nil, connect.NewError(connect.CodeInternal,
			fmt.Errorf("payments: list: %w", err))
	}

	resp := &posv1.GetSaleResponse{
		Invoice: invoiceToProto(inv),
		Lines:   getSaleLinesFromSnapshot(snap.GetLines()),
		Payments: getSalePaymentsFromDomain(pays),
	}
	return connect.NewResponse(resp), nil
}

func getSaleLinesFromSnapshot(in []*posv1.SaleLine) []*posv1.GetSaleLine {
	out := make([]*posv1.GetSaleLine, 0, len(in))
	for _, l := range in {
		out = append(out, &posv1.GetSaleLine{
			LineId:      l.GetLineId(),
			Sku:         l.GetSku(),
			Description: l.GetDescription(),
			Quantity:    l.GetQuantity(),
			UnitPrice:   l.GetUnitPrice(),
			LineTotal:   l.GetLineTotal(),
		})
	}
	return out
}

func getSalePaymentsFromDomain(in []payments.Payment) []*posv1.GetSalePayment {
	out := make([]*posv1.GetSalePayment, 0, len(in))
	for _, p := range in {
		// Skip refund-side rows — caller wants the original tenders.
		if p.ParentPaymentID != uuid.Nil {
			continue
		}
		if p.Amount.Sign() < 0 {
			continue
		}
		out = append(out, &posv1.GetSalePayment{
			PaymentId: p.PaymentID.String(),
			Method:    string(p.Method),
			Amount:    moneyToProto(p.Amount),
			Reference: p.Reference,
		})
	}
	return out
}

// --- proto → domain conversions ---

func saleLinesFromProto(in []*posv1.FinalizeSaleLine) ([]sales.SaleLine, error) {
	out := make([]sales.SaleLine, 0, len(in))
	for i, ln := range in {
		if ln == nil {
			return nil, fmt.Errorf("lines[%d]: nil", i)
		}
		lineID, err := uuid.Parse(ln.GetLineId())
		if err != nil {
			return nil, fmt.Errorf("lines[%d].line_id: %w", i, err)
		}
		out = append(out, sales.SaleLine{
			LineID:        lineID,
			SKU:           ln.GetSku(),
			Description:   ln.GetDescription(),
			Quantity:      ln.GetQuantity(),
			UnitPrice:     moneyFromProto(ln.GetUnitPrice()),
			LineTotal:     moneyFromProto(ln.GetLineTotal()),
			TaxCategoryID: ln.GetTaxCategoryId(),
		})
	}
	return out, nil
}

func parseReservationIDs(in []string) ([]uuid.UUID, error) {
	if len(in) == 0 {
		return nil, nil
	}
	out := make([]uuid.UUID, 0, len(in))
	for i, s := range in {
		id, err := uuid.Parse(s)
		if err != nil {
			return nil, fmt.Errorf("reservation_ids[%d]: %w", i, err)
		}
		out = append(out, id)
	}
	return out, nil
}

func saleTendersFromProto(in []*posv1.FinalizeSaleTender) ([]sales.Tender, error) {
	out := make([]sales.Tender, 0, len(in))
	for i, t := range in {
		if t == nil {
			return nil, fmt.Errorf("tenders[%d]: nil", i)
		}
		payID, err := uuid.Parse(t.GetPaymentId())
		if err != nil {
			return nil, fmt.Errorf("tenders[%d].payment_id: %w", i, err)
		}
		out = append(out, sales.Tender{
			PaymentID: payID,
			Method:    payments.Method(t.GetMethod()),
			Amount:    moneyFromProto(t.GetAmount()),
			Reference: t.GetReference(),
		})
	}
	return out, nil
}

// --- domain → proto conversions ---

func invoiceToProto(inv invoices.Invoice) *posv1.Invoice {
	return &posv1.Invoice{
		InvoiceId:     inv.InvoiceID.String(),
		SaleId:        inv.SaleID.String(),
		InvoiceNumber: inv.InvoiceNumber,
		StoreId:       &posv1.StoreId{Value: inv.StoreID},
		CounterId:     &posv1.CounterId{Value: inv.CounterID},
		CashierId:     &posv1.UserId{Value: inv.CashierID},
		Subtotal:      moneyToProto(inv.Subtotal),
		TaxTotal:      moneyToProto(inv.TaxTotal),
		GrandTotal:    moneyToProto(inv.GrandTotal),
		Snapshot:      inv.Snapshot,
		FinalizedAt:   timeToProto(inv.FinalizedAt),
	}
}
