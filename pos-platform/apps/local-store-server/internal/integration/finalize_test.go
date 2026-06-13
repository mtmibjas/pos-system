// Package integration holds cross-layer tests that prove the atomic-batch
// contract from docs/sync-rules.md ("Batching — atomic groups"):
//
//	A sale finalization must persist opslog + inventory + payments
//	together, or not at all.
//
// These tests exercise the real opslog/inventory/payments stores composed
// through txn.Apply — i.e. exactly the path the future SaleService will use.
package integration_test

import (
	"context"
	"database/sql"
	"errors"
	"path/filepath"
	"testing"
	"time"

	"github.com/google/uuid"
	"github.com/stretchr/testify/require"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/db"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/syncstate"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"

	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

const nodeID = "node-integration"

type stores struct {
	db    *sql.DB
	ops   *opslog.Store
	inv   *inventory.Store
	pays  *payments.Store
	state *syncstate.Store
	clk   *clock.Lamport
}

func newStores(t *testing.T) *stores {
	t.Helper()
	ctx := context.Background()
	path := filepath.Join(t.TempDir(), "integration.db")
	sqlDB, err := db.Open(ctx, db.Config{Path: path})
	require.NoError(t, err)
	t.Cleanup(func() { _ = sqlDB.Close() })
	require.NoError(t, db.RunMigrations(sqlDB))
	state := syncstate.NewStore(sqlDB)
	clk, err := clock.New(ctx, state)
	require.NoError(t, err)
	return &stores{
		db:    sqlDB,
		ops:   opslog.NewStore(sqlDB),
		inv:   inventory.NewStore(sqlDB, nil),
		pays:  payments.NewStore(sqlDB),
		state: state,
		clk:   clk,
	}
}

// receive stocks a SKU by N (its own atomic op so the sale tests start clean).
func receive(t *testing.T, s *stores, storeID, sku string, qty int64) {
	t.Helper()
	require.NoError(t, s.inv.Append(context.Background(), inventory.Movement{
		MovementID:   uuid.New(),
		SKU:          sku,
		StoreID:      storeID,
		Delta:        qty,
		Reason:       inventory.ReasonReceive,
		RefType:      "receive",
		RefID:        uuid.NewString(),
		OccurredAt:   time.Now().UTC(),
		Lamport:      1,
		OriginNodeID: nodeID,
	}))
}

// finalizeSale is the integration shim — *not* the real SaleService, just
// the minimum that composes the three writes through txn.Apply. The future
// SaleService will look like this, plus tax + full event payload construction.
func finalizeSale(
	ctx context.Context,
	s *stores,
	storeID, sku string,
	qty int64,
	pay payments.Payment,
	saleOpID uuid.UUID,
	injectFailure error, // optional — simulates a downstream failure mid-batch
) error {
	return s.inv.WithSKULock(storeID, sku, func() error {
		// Build the SaleCreated event + envelope outside the tx (cheap, pure).
		lamport, err := s.clk.Next(ctx)
		if err != nil {
			return err
		}
		sale := &posv1.SaleCreated{
			SaleId:  saleOpID.String(),
			StoreId: &posv1.StoreId{Value: storeID},
			Lines: []*posv1.SaleLine{
				{Sku: sku, Quantity: qty, UnitPrice: &posv1.Money{CurrencyCode: pay.Amount.CurrencyCode, Units: pay.Amount.Units / qty}},
			},
			GrandTotal: &posv1.Money{
				CurrencyCode: pay.Amount.CurrencyCode,
				Units:        pay.Amount.Units,
				Nanos:        pay.Amount.Nanos,
			},
		}
		_, wire, err := events.Pack(sale, events.Meta{
			OperationID: saleOpID.String(),
			TenantID:    "tenant-A",
			OriginNode:  &posv1.OriginNode{NodeId: nodeID, StoreId: &posv1.StoreId{Value: storeID}},
			Lamport:     lamport,
			OccurredAt:  time.Now().UTC(),
		})
		if err != nil {
			return err
		}

		return txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
			// 1. opslog: SaleCreated event (typed envelope wire bytes)
			_, _, err := s.ops.InsertTx(ctx, tx, opslog.Operation{
				OperationID:   saleOpID,
				OperationType: "sale_created",
				EntityType:    "sale",
				EntityID:      saleOpID.String(),
				Payload:       wire,
				CreatedAt:     time.Now().UTC(),
				Lamport:       lamport,
				OriginNodeID:  nodeID,
			})
			if err != nil {
				return err
			}
			// 2. inventory: ledger decrement
			if err := s.inv.AppendTx(ctx, tx, inventory.Movement{
				MovementID:   uuid.New(),
				SKU:          sku,
				StoreID:      storeID,
				Delta:        -qty,
				Reason:       inventory.ReasonSale,
				RefType:      "sale",
				RefID:        saleOpID.String(),
				OccurredAt:   time.Now().UTC(),
				Lamport:      lamport,
				OriginNodeID: nodeID,
			}); err != nil {
				return err
			}
			// 3. payments: tender row
			if _, _, err := s.pays.InsertTx(ctx, tx, pay); err != nil {
				return err
			}
			// Optional injected failure (simulating a downstream step blowing up).
			if injectFailure != nil {
				return injectFailure
			}
			return nil
		})
	})
}

func TestSaleFinalization_AllOrNothing_Commits(t *testing.T) {
	s := newStores(t)
	ctx := context.Background()
	storeID, sku := "store-A", "SKU1"
	receive(t, s, storeID, sku, 10)

	saleOp := uuid.New()
	pay := payments.Payment{
		PaymentID: uuid.New(),
		SaleID:    saleOp,
		Method:    payments.MethodCash,
		Amount:    payments.Money{CurrencyCode: "USD", Units: 10, Nanos: 0},
		CreatedAt: time.Now().UTC(),
	}
	require.NoError(t, finalizeSale(ctx, s, storeID, sku, 3, pay, saleOp, nil))

	// All three writes landed.
	stock, _ := s.inv.StockOnHand(ctx, storeID, sku)
	require.Equal(t, int64(7), stock, "stock decremented by 3")

	bal, _ := s.pays.Balance(ctx, saleOp)
	require.Equal(t, payments.Money{"USD", 10, 0}, bal)

	op, err := s.ops.Get(ctx, saleOp)
	require.NoError(t, err)
	require.Equal(t, opslog.StatusPending, op.SyncStatus)

	// And the persisted Payload is a real typed envelope, not stub JSON.
	env, inner, err := events.Unpack(op.Payload)
	require.NoError(t, err)
	require.Equal(t, "sale_created", env.EventType)
	sale, ok := inner.(*posv1.SaleCreated)
	require.True(t, ok)
	require.Equal(t, saleOp.String(), sale.SaleId)
	require.Equal(t, sku, sale.Lines[0].Sku)
	require.Equal(t, int64(3), sale.Lines[0].Quantity)
}

func TestSaleFinalization_AllOrNothing_RollsBack(t *testing.T) {
	s := newStores(t)
	ctx := context.Background()
	storeID, sku := "store-A", "SKU1"
	receive(t, s, storeID, sku, 10)

	saleOp := uuid.New()
	pay := payments.Payment{
		PaymentID: uuid.New(),
		SaleID:    saleOp,
		Method:    payments.MethodCash,
		Amount:    payments.Money{CurrencyCode: "USD", Units: 10, Nanos: 0},
		CreatedAt: time.Now().UTC(),
	}
	boom := errors.New("simulated downstream failure (e.g. ws publish)")
	err := finalizeSale(ctx, s, storeID, sku, 3, pay, saleOp, boom)
	require.ErrorIs(t, err, boom)

	// None of the three writes survived.
	stock, _ := s.inv.StockOnHand(ctx, storeID, sku)
	require.Equal(t, int64(10), stock, "stock unchanged — inventory write rolled back")

	bal, _ := s.pays.Balance(ctx, saleOp)
	require.True(t, bal.IsZero(), "no payment row — rolled back")

	_, err = s.ops.Get(ctx, saleOp)
	require.ErrorIs(t, err, opslog.ErrNotFound, "no opslog row — rolled back")
}

func TestSaleFinalization_OversellRejectsWholeBatch(t *testing.T) {
	// If inventory step would oversell, the entire batch (including the
	// opslog row and the payment row) must roll back — there is no
	// "partial sale" state.
	s := newStores(t)
	ctx := context.Background()
	storeID, sku := "store-A", "SKU1"
	receive(t, s, storeID, sku, 2)

	saleOp := uuid.New()
	pay := payments.Payment{
		PaymentID: uuid.New(),
		SaleID:    saleOp,
		Method:    payments.MethodCash,
		Amount:    payments.Money{CurrencyCode: "USD", Units: 50, Nanos: 0},
		CreatedAt: time.Now().UTC(),
	}
	err := finalizeSale(ctx, s, storeID, sku, 5, pay, saleOp, nil)
	var oerr *inventory.OversellError
	require.ErrorAs(t, err, &oerr)

	// Inventory unchanged.
	stock, _ := s.inv.StockOnHand(ctx, storeID, sku)
	require.Equal(t, int64(2), stock)
	// No payment row.
	bal, _ := s.pays.Balance(ctx, saleOp)
	require.True(t, bal.IsZero())
	// No opslog row.
	_, err = s.ops.Get(ctx, saleOp)
	require.ErrorIs(t, err, opslog.ErrNotFound)
}

func TestSaleFinalization_IdempotentOnReplay(t *testing.T) {
	// Replaying the same sale (same OperationID + same PaymentID) must
	// converge: opslog returns idempotent=true, payment returns
	// idempotent=true, and inventory does NOT double-decrement.
	//
	// The current finalizeSale shim doesn't yet de-dupe inventory by
	// MovementID — a real SaleService will key the inventory MovementID
	// off the SaleID so retries collide on the inventory_movements PK
	// too. For Phase 1 we only assert the opslog+payments halves, and
	// document the inventory replay handling as a Phase 3 (event-driven
	// SaleService) requirement.
	s := newStores(t)
	ctx := context.Background()
	storeID, sku := "store-A", "SKU1"
	receive(t, s, storeID, sku, 10)

	saleOp := uuid.New()
	payID := uuid.New()
	makePay := func() payments.Payment {
		return payments.Payment{
			PaymentID: payID,
			SaleID:    saleOp,
			Method:    payments.MethodCash,
			Amount:    payments.Money{CurrencyCode: "USD", Units: 10, Nanos: 0},
			CreatedAt: time.Now().UTC(),
		}
	}

	require.NoError(t, finalizeSale(ctx, s, storeID, sku, 3, makePay(), saleOp, nil))

	// First sale recorded.
	op1, err := s.ops.Get(ctx, saleOp)
	require.NoError(t, err)

	// Replay with the same opIDs.
	// We re-call finalizeSale but pass a fresh inventory movement id inside
	// the shim — so this *is* a double-decrement and we expect it. We assert
	// the opslog + payment halves are idempotent; the inventory de-dupe
	// belongs to the real SaleService (Phase 3).
	_ = finalizeSale(ctx, s, storeID, sku, 3, makePay(), saleOp, nil)

	op2, err := s.ops.Get(ctx, saleOp)
	require.NoError(t, err)
	require.Equal(t, op1.OperationID, op2.OperationID)

	// Payment balance is still $10 (not $20) — InsertTx is idempotent on PaymentID.
	bal, _ := s.pays.Balance(ctx, saleOp)
	require.Equal(t, payments.Money{"USD", 10, 0}, bal)
}
