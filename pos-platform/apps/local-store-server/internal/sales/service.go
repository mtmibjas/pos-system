// Package sales is the producer for sale events.
//
// The Phase 1 sync engine ships ops; this package is what creates them.
// Service.Finalize is the canonical entry point: it takes a draft sale
// (lines + tenders), validates the arithmetic, acquires per-SKU locks,
// then writes the atomic trio inside one txn.Apply under one fresh
// BatchID:
//
//	1. SaleCreated (opslog only)
//	2. InventoryAdjusted per line (opslog + inventory.AppendTx)
//	3. PaymentAdded per tender (opslog + payments.InsertTx)
//
// On commit, Notifier.Notify wakes the sync worker so the new ops ship
// inside milliseconds rather than waiting for the next tick.
//
// Out of scope for this slice (each has its own follow-up slice):
//   - Tax engine — for now LineTax/TaxTotal are caller-supplied passthroughs.
//   - invoices table immutability — the "invoice" is currently just the
//     SaleCreated op + its ledger rows.
//   - Refunds / voids.
//   - HTTP API surface (Connect-RPC) — tested directly in Go for now.
package sales

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"sort"
	"time"

	"github.com/google/uuid"
	"google.golang.org/protobuf/proto"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/clock"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/events"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/hub"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Service is the sale-finalization producer. One per local-store-server.
type Service struct {
	db           *sql.DB
	ops          *opslog.Store
	inv          *inventory.Store
	pays         *payments.Store
	invs         *invoices.Store
	tax          *tax.Engine
	clk          *clock.Lamport
	notifier     Notifier
	publisher    hub.Publisher
	reservations *reservations.Service // nil = no reservation consumption
	nodeID       string
	tenantID     string
}

// Config groups the constructor inputs so future fields (logger, metrics,
// per-tenant policy hooks) land without breaking callers.
type Config struct {
	DB        *sql.DB
	Ops       *opslog.Store
	Inv       *inventory.Store
	Pays      *payments.Store
	Invoices  *invoices.Store
	Tax       *tax.Engine
	Clock     *clock.Lamport
	Notifier  Notifier      // nil → NoopNotifier (useful in tests and dry-runs)
	Publisher hub.Publisher // nil → hub.NopPublisher; receives every committed event post-commit

	// Reservations is the optional 4.3 hold consumer. When non-nil and
	// FinalizeRequest.ReservationIDs is non-empty, Finalize flips each
	// reservation to 'finalized' inside the sale's txn.Apply. Any unknown
	// or non-active id rolls the whole sale back.
	Reservations *reservations.Service

	NodeID   string // stable per-device install id (required)
	TenantID string // multi-tenant routing key (required)
}

// NewService validates required fields and returns a Service.
func NewService(c Config) (*Service, error) {
	switch {
	case c.DB == nil:
		return nil, errors.New("sales: Config.DB is required")
	case c.Ops == nil:
		return nil, errors.New("sales: Config.Ops is required")
	case c.Inv == nil:
		return nil, errors.New("sales: Config.Inv is required")
	case c.Pays == nil:
		return nil, errors.New("sales: Config.Pays is required")
	case c.Invoices == nil:
		return nil, errors.New("sales: Config.Invoices is required")
	case c.Tax == nil:
		return nil, errors.New("sales: Config.Tax is required")
	case c.Clock == nil:
		return nil, errors.New("sales: Config.Clock is required")
	case c.NodeID == "":
		return nil, errors.New("sales: Config.NodeID is required")
	case c.TenantID == "":
		return nil, ErrEmptyTenant
	}
	if c.Notifier == nil {
		c.Notifier = NoopNotifier{}
	}
	if c.Publisher == nil {
		c.Publisher = hub.NopPublisher{}
	}
	return &Service{
		db:           c.DB,
		ops:          c.Ops,
		inv:          c.Inv,
		pays:         c.Pays,
		invs:         c.Invoices,
		tax:          c.Tax,
		clk:          c.Clock,
		notifier:     c.Notifier,
		publisher:    c.Publisher,
		reservations: c.Reservations,
		nodeID:       c.NodeID,
		tenantID:     c.TenantID,
	}, nil
}

// FinalizeRequest is the in-process input to Finalize. Future API layers
// (Slice 2.5) translate posv1.* wire messages into this domain shape.
type FinalizeRequest struct {
	SaleID     uuid.UUID
	StoreID    string
	CounterID  string // optional
	CashierID  string // optional
	Lines      []SaleLine
	Tenders    []Tender

	// Subtotal = Σ line totals. Caller supplies it so we can detect drift
	// between what they computed and what we'd recompute (instead of
	// silently disagreeing).
	// Subtotal / TaxTotal / GrandTotal are OPTIONAL. The tax engine
	// recomputes them server-side from the line categories. If the caller
	// supplies any of them with a non-zero value, it must equal the
	// engine's output — otherwise Finalize returns an ErrTotalsMismatch.
	// Existing callers that already compute totals client-side keep working;
	// new callers can pass zero-valued Money and let the engine fill them in.
	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money

	OccurredAt time.Time // wall-clock; lamport overrides for ordering

	// ReservationIDs are active holds the cart is consuming (slice 4.3).
	// Finalized atomically with the sale; any non-active id rolls the
	// whole txn back with FailedPrecondition semantics.
	ReservationIDs []uuid.UUID
}

// SaleLine is one line of a sale.
//
// LineTotal must equal UnitPrice * Quantity. Its tax-relationship depends on
// the line's TaxCategoryID:
//   - Empty / category with no rate / category with PriceIncludesTax=false:
//     LineTotal is the pre-tax (NET) amount.
//   - Category with PriceIncludesTax=true:
//     LineTotal is the tax-inclusive (GROSS) amount; the tax engine
//     extracts net from it.
//
// Either way, the customer-facing receipt's grand total = Σ each line's
// gross, and the engine is server-authoritative on the split.
type SaleLine struct {
	LineID        uuid.UUID
	SKU           string
	Description   string
	Quantity      int64 // positive for a sale
	UnitPrice     payments.Money
	LineTotal     payments.Money // = UnitPrice * Quantity; validated
	TaxCategoryID string         // "" = exempt; otherwise must resolve via tax.Store
}

// Tender is one payment instrument applied to a sale.
type Tender struct {
	PaymentID uuid.UUID
	Method    payments.Method
	Amount    payments.Money // positive (refunds land via Slice 2.4)
	Reference string         // gateway txn id, cheque #, etc. (optional)
}

// FinalizeResponse reports the outcome of a Finalize call.
type FinalizeResponse struct {
	SaleID     uuid.UUID
	BatchID    uuid.UUID
	Lamport    uint64
	Invoice    invoices.Invoice
	Idempotent bool // true if the same SaleID was already finalized previously
}

// Finalize is the canonical entry point. See package doc for the contract.
func (s *Service) Finalize(ctx context.Context, req FinalizeRequest) (FinalizeResponse, error) {
	currency, err := s.validate(req)
	if err != nil {
		return FinalizeResponse{}, err
	}

	// Idempotency: if the SaleCreated op for this SaleID already exists,
	// short-circuit. Caller-side retries (e.g. UI tapping "Pay" twice) must
	// not produce a second physical sale.
	if existing, ok, err := s.lookupExistingSale(ctx, req.SaleID); err != nil {
		return FinalizeResponse{}, err
	} else if ok {
		return existing, nil
	}

	// Server-authoritative tax computation. The engine resolves each line's
	// tax_category and returns net / tax / gross plus a breakdown. Caller-
	// supplied non-zero totals must match (otherwise ErrTotalsMismatch).
	taxResp, err := s.tax.Compute(ctx, tax.ComputeRequest{
		TenantID:   s.tenantID,
		StoreID:    req.StoreID,
		Lines:      toComputeLines(req.Lines),
		OccurredAt: req.OccurredAt,
	})
	if err != nil {
		return FinalizeResponse{}, fmt.Errorf("sales: tax compute: %w", err)
	}
	if err := validateAgainstEngine(req, taxResp); err != nil {
		return FinalizeResponse{}, err
	}
	if err := validateTenderSum(currency, req.Tenders, taxResp.GrandTotal); err != nil {
		return FinalizeResponse{}, err
	}

	// From here on, the engine's totals are authoritative — replace any
	// caller-supplied (or zero) totals with the computed values.
	effective := req
	effective.Subtotal = taxResp.Subtotal
	effective.TaxTotal = taxResp.TaxTotal
	effective.GrandTotal = taxResp.GrandTotal

	batchID := uuid.New()
	lamport, err := s.clk.Next(ctx) // single lamport for the whole atomic batch
	if err != nil {
		return FinalizeResponse{}, fmt.Errorf("sales: lamport next: %w", err)
	}

	// Build the SaleCreated proto once — used as both the opslog payload
	// and the invoice snapshot so the two never disagree. taxResp.Lines is
	// 1-to-1 with effective.Lines (engine guarantee) so the per-line tax
	// breakdown can ride on the wire without a second pass.
	saleProto := buildSaleCreated(effective, taxResp.Lines)

	// Acquire per-SKU locks up front, in deterministic order, to prevent
	// deadlocks when two finalizations touch the same set of SKUs.
	unlock := s.lockSKUs(req.StoreID, uniqueSKUs(req.Lines))
	defer unlock()

	var invoice invoices.Invoice
	err = txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		// 1) SaleCreated.
		if err := s.writeSaleCreated(ctx, tx, req, saleProto, batchID, lamport); err != nil {
			return fmt.Errorf("sale_created: %w", err)
		}
		// 2) InventoryAdjusted per line (opslog + inventory ledger).
		for _, line := range req.Lines {
			if err := s.writeInventoryAdjusted(ctx, tx, req, line, batchID, lamport); err != nil {
				return fmt.Errorf("inventory_adjusted sku=%s: %w", line.SKU, err)
			}
		}
		// 3) PaymentAdded per tender (opslog + payments ledger).
		for _, t := range req.Tenders {
			if err := s.writePaymentAdded(ctx, tx, req, t, batchID, lamport); err != nil {
				return fmt.Errorf("payment_added pid=%s: %w", t.PaymentID, err)
			}
		}
		// 3.5) Finalize any held reservations atomically with the sale
		// (slice 4.3). A stale / non-active id rolls the entire sale back —
		// the cart must reload.
		if s.reservations != nil {
			for _, rid := range req.ReservationIDs {
				if rid == uuid.Nil {
					return fmt.Errorf("reservation_id: nil")
				}
				if _, err := s.reservations.FinalizeTx(ctx, tx, rid); err != nil {
					return fmt.Errorf("reservation %s: %w", rid, err)
				}
			}
		}
		// 4) Invoice projection. Issued under the same tx so the receipt
		// and the events commit together.
		inv, ierr := s.invs.IssueTx(ctx, tx, invoices.IssueRequest{
			InvoiceID:   uuid.New(),
			SaleID:      effective.SaleID,
			StoreID:     effective.StoreID,
			CounterID:   effective.CounterID,
			CashierID:   effective.CashierID,
			Subtotal:    effective.Subtotal,
			TaxTotal:    effective.TaxTotal,
			GrandTotal:  effective.GrandTotal,
			Snapshot:    saleProto,
			FinalizedAt: effective.OccurredAt,
		})
		if ierr != nil {
			return fmt.Errorf("invoice: %w", ierr)
		}
		invoice = inv
		return nil
	})
	if err != nil {
		return FinalizeResponse{}, err
	}

	// Wake the worker so the new BatchID ships immediately.
	s.notifier.Notify()

	// Fan the just-committed events out to in-process realtime subscribers
	// (Phase 4 slice 4.2). Best-effort: read errors are not fatal — opslog
	// has the canonical record and 4.4's reconnect-with-last-seen lets any
	// client that missed a broadcast catch up.
	s.broadcastBatch(ctx, batchID)

	// Reservation finalization changes available-qty for the held SKUs
	// (slice 4.3). Broadcast post-commit so a rollback can't fire a
	// spurious "available went up" frame. Each affected SKU gets one
	// inventory_available_changed frame.
	if s.reservations != nil && len(req.ReservationIDs) > 0 {
		seen := make(map[string]struct{}, len(req.Lines))
		for _, l := range req.Lines {
			key := req.StoreID + "\x00" + l.SKU
			if _, ok := seen[key]; ok {
				continue
			}
			seen[key] = struct{}{}
			s.reservations.PublishAvailableChange(ctx, req.StoreID, l.SKU)
		}
	}

	return FinalizeResponse{
		SaleID:  req.SaleID,
		BatchID: batchID,
		Lamport: lamport,
		Invoice: invoice,
	}, nil
}

// broadcastBatch reads every operation tagged with batchID from opslog,
// unpacks each payload back into its EventEnvelope, and publishes to the
// hub. Designed to be called immediately after a successful txn.Apply.
//
// Errors are intentionally swallowed: the sale is already committed and
// durably synced via the opslog path, so a broken realtime broadcast must
// not roll back or surface to the caller. Subscribers that missed the
// fan-out recover via the 4.4 reconnect path.
func (s *Service) broadcastBatch(ctx context.Context, batchID uuid.UUID) {
	ops, err := s.ops.ListByBatch(ctx, batchID)
	if err != nil {
		return
	}
	for _, op := range ops {
		env, _, err := events.Unpack(op.Payload)
		if err != nil {
			continue
		}
		s.publisher.Publish(env)
	}
}

// --- internals ---

// validate runs the structural checks that are independent of tax. The
// tax-dependent checks (subtotal/grand totals, tender sum vs grand) run
// against the engine's authoritative output in Finalize after this returns.
//
// Returned currency is the sale's currency, derived from line / tender data
// (since Subtotal may be zero-valued for engine-driven callers).
func (s *Service) validate(req FinalizeRequest) (string, error) {
	if req.SaleID == uuid.Nil {
		return "", ErrNilSaleID
	}
	if req.StoreID == "" {
		return "", errors.New("sales: StoreID is required")
	}
	if req.OccurredAt.IsZero() {
		return "", errors.New("sales: OccurredAt is required")
	}
	if len(req.Lines) == 0 {
		return "", ErrNoLines
	}
	if len(req.Tenders) == 0 {
		return "", ErrNoTenders
	}

	// Derive currency from the first line (Subtotal may be zero-valued).
	currency := req.Lines[0].LineTotal.CurrencyCode
	if currency == "" {
		return "", errors.New("sales: line currency is required")
	}

	// Per-line structural checks + LineTotal arithmetic.
	for _, line := range req.Lines {
		if line.LineID == uuid.Nil {
			return "", errors.New("sales: SaleLine.LineID is required")
		}
		if line.SKU == "" {
			return "", errors.New("sales: SaleLine.SKU is required")
		}
		if line.Quantity <= 0 {
			return "", ErrNonPositiveQty
		}
		if line.UnitPrice.CurrencyCode != currency || line.LineTotal.CurrencyCode != currency {
			return "", ErrCurrencyMix
		}
		expected, err := line.UnitPrice.Mul(line.Quantity)
		if err != nil {
			return "", fmt.Errorf("sales: line %s: %w", line.SKU, err)
		}
		if !expected.Equal(line.LineTotal) {
			return "", &ErrLineTotalMismatch{
				SKU:      line.SKU,
				Expected: formatMoney(expected),
				Got:      formatMoney(line.LineTotal),
			}
		}
	}

	// Tender per-item validation; sum vs grand happens after tax compute.
	for _, t := range req.Tenders {
		if t.PaymentID == uuid.Nil {
			return "", errors.New("sales: Tender.PaymentID is required")
		}
		if t.Method == "" {
			return "", errors.New("sales: Tender.Method is required")
		}
		if t.Amount.CurrencyCode != currency {
			return "", ErrCurrencyMix
		}
		if t.Amount.Sign() <= 0 {
			// Refunds (negative amounts) belong to Slice 2.4, not Finalize.
			return "", errors.New("sales: Tender.Amount must be positive in Finalize")
		}
	}

	// Caller-supplied totals (if non-zero) must use the sale's currency.
	for name, m := range map[string]payments.Money{
		"Subtotal":   req.Subtotal,
		"TaxTotal":   req.TaxTotal,
		"GrandTotal": req.GrandTotal,
	} {
		if m.CurrencyCode != "" && m.CurrencyCode != currency {
			return "", fmt.Errorf("sales: %s currency %q ≠ line currency %q", name, m.CurrencyCode, currency)
		}
	}
	return currency, nil
}

// validateAgainstEngine cross-checks caller-supplied totals (if non-zero)
// against the tax engine's authoritative output. Zero-valued caller money
// short-circuits — the engine fills it in downstream.
func validateAgainstEngine(req FinalizeRequest, taxResp tax.ComputeResponse) error {
	check := func(name string, caller, computed payments.Money) error {
		if caller.IsZero() {
			return nil
		}
		if !caller.Equal(computed) {
			return &ErrTotalsMismatch{
				Field:    name,
				Caller:   formatMoney(caller),
				Computed: formatMoney(computed),
			}
		}
		return nil
	}
	if err := check("Subtotal", req.Subtotal, taxResp.Subtotal); err != nil {
		return err
	}
	if err := check("TaxTotal", req.TaxTotal, taxResp.TaxTotal); err != nil {
		return err
	}
	if err := check("GrandTotal", req.GrandTotal, taxResp.GrandTotal); err != nil {
		return err
	}
	return nil
}

// validateTenderSum verifies Σ tender amounts == engine grand total.
func validateTenderSum(currency string, tenders []Tender, grandTotal payments.Money) error {
	sum := payments.Money{CurrencyCode: currency}
	for _, t := range tenders {
		var err error
		sum, err = sum.Add(t.Amount)
		if err != nil {
			return fmt.Errorf("sales: tender accum: %w", err)
		}
	}
	if !sum.Equal(grandTotal) {
		return &ErrGrandTotalMismatch{
			GrandTotal: formatMoney(grandTotal),
			TenderSum:  formatMoney(sum),
		}
	}
	return nil
}

// lookupExistingSale returns the prior outcome if this SaleID was already
// finalized. We key idempotency on opslog: the SaleCreated op_id == saleID.
// The invoice is loaded so the caller's response shape matches a fresh
// finalize.
func (s *Service) lookupExistingSale(ctx context.Context, saleID uuid.UUID) (FinalizeResponse, bool, error) {
	op, err := s.ops.Get(ctx, saleID)
	if errors.Is(err, opslog.ErrNotFound) {
		return FinalizeResponse{}, false, nil
	}
	if err != nil {
		return FinalizeResponse{}, false, fmt.Errorf("sales: idempotency lookup: %w", err)
	}
	if op.OperationType != "sale_created" {
		return FinalizeResponse{}, false, fmt.Errorf(
			"sales: SaleID %s collides with existing op of type %q", saleID, op.OperationType)
	}
	inv, err := s.invs.GetBySale(ctx, saleID)
	if err != nil {
		return FinalizeResponse{}, false, fmt.Errorf("sales: load prior invoice: %w", err)
	}
	return FinalizeResponse{
		SaleID:     saleID,
		BatchID:    op.BatchID,
		Lamport:    op.Lamport,
		Invoice:    inv,
		Idempotent: true,
	}, true, nil
}

func (s *Service) writeSaleCreated(ctx context.Context, tx *sql.Tx, req FinalizeRequest, sale *posv1.SaleCreated, batchID uuid.UUID, lamport uint64) error {
	return s.packAndInsertOp(ctx, tx, opCommon{
		operationID:   req.SaleID, // SaleID == SaleCreated op id (idempotency key)
		operationType: "sale_created",
		entityType:    "sale",
		entityID:      req.SaleID.String(),
		payload:       sale,
		batchID:       batchID,
		lamport:       lamport,
		occurredAt:    req.OccurredAt,
	})
}

// buildSaleCreated assembles the canonical SaleCreated proto from the
// validated request. Used both as the opslog payload and the invoice
// snapshot — single source so they cannot drift. lineTax is 1-to-1
// with req.Lines (the tax engine's contract); pass an empty slice when
// tax is not applicable.
func buildSaleCreated(req FinalizeRequest, lineTax []tax.LineTax) *posv1.SaleCreated {
	return &posv1.SaleCreated{
		SaleId:     req.SaleID.String(),
		StoreId:    &posv1.StoreId{Value: req.StoreID},
		CounterId:  &posv1.CounterId{Value: req.CounterID},
		CashierId:  &posv1.UserId{Value: req.CashierID},
		Lines:      toProtoLines(req.Lines, lineTax),
		Subtotal:   toProtoMoney(req.Subtotal),
		TaxTotal:   toProtoMoney(orZeroMoney(req.TaxTotal, req.Subtotal.CurrencyCode)),
		GrandTotal: toProtoMoney(req.GrandTotal),
	}
}

func (s *Service) writeInventoryAdjusted(ctx context.Context, tx *sql.Tx, req FinalizeRequest, line SaleLine, batchID uuid.UUID, lamport uint64) error {
	movementID := line.LineID // re-use the line UUID for the inventory movement id

	adjusted := &posv1.InventoryAdjusted{
		Sku:    line.SKU,
		Delta:  -line.Quantity,
		Reason: string(inventory.ReasonSale),
		RefId:  req.SaleID.String(),
	}
	if err := s.packAndInsertOp(ctx, tx, opCommon{
		operationID:   movementID,
		operationType: "inventory_adjusted",
		entityType:    "inventory",
		entityID:      line.SKU,
		payload:       adjusted,
		batchID:       batchID,
		lamport:       lamport,
		occurredAt:    req.OccurredAt,
	}); err != nil {
		return err
	}

	return s.inv.AppendTx(ctx, tx, inventory.Movement{
		MovementID:   movementID,
		SKU:          line.SKU,
		StoreID:      req.StoreID,
		CounterID:    req.CounterID,
		Delta:        -line.Quantity,
		Reason:       inventory.ReasonSale,
		RefType:      "sale",
		RefID:        req.SaleID.String(),
		OccurredAt:   req.OccurredAt,
		Lamport:      lamport,
		OriginNodeID: s.nodeID,
	})
}

func (s *Service) writePaymentAdded(ctx context.Context, tx *sql.Tx, req FinalizeRequest, t Tender, batchID uuid.UUID, lamport uint64) error {
	payAdded := &posv1.PaymentAdded{
		PaymentId: t.PaymentID.String(),
		SaleId:    req.SaleID.String(),
		Method:    string(t.Method),
		Amount:    toProtoMoney(t.Amount),
		Reference: t.Reference,
	}
	if err := s.packAndInsertOp(ctx, tx, opCommon{
		operationID:   t.PaymentID,
		operationType: "payment_added",
		entityType:    "payment",
		entityID:      t.PaymentID.String(),
		payload:       payAdded,
		batchID:       batchID,
		lamport:       lamport,
		occurredAt:    req.OccurredAt,
	}); err != nil {
		return err
	}

	_, _, err := s.pays.InsertTx(ctx, tx, payments.Payment{
		PaymentID: t.PaymentID,
		SaleID:    req.SaleID,
		Method:    t.Method,
		Amount:    t.Amount,
		Reference: t.Reference,
		CreatedAt: req.OccurredAt,
	})
	return err
}

// opCommon groups the per-op fields packAndInsertOp needs. Avoids a long
// positional arg list.
type opCommon struct {
	operationID   uuid.UUID
	operationType string
	entityType    string
	entityID      string
	payload       proto.Message
	batchID       uuid.UUID
	lamport       uint64
	occurredAt    time.Time
}

func (s *Service) packAndInsertOp(ctx context.Context, tx *sql.Tx, c opCommon) error {
	_, wire, err := events.Pack(c.payload, events.Meta{
		OperationID: c.operationID.String(),
		TenantID:    s.tenantID,
		OriginNode:  &posv1.OriginNode{NodeId: s.nodeID, StoreId: nil, CounterId: nil},
		Lamport:     c.lamport,
		OccurredAt:  c.occurredAt,
	})
	if err != nil {
		return fmt.Errorf("pack: %w", err)
	}
	_, _, err = s.ops.InsertTx(ctx, tx, opslog.Operation{
		OperationID:   c.operationID,
		OperationType: c.operationType,
		EntityType:    c.entityType,
		EntityID:      c.entityID,
		Payload:       wire,
		CreatedAt:     c.occurredAt,
		Lamport:       c.lamport,
		OriginNodeID:  s.nodeID,
		BatchID:       c.batchID,
	})
	return err
}

// lockSKUs grabs every per-SKU lock in sorted order to avoid deadlocks
// (the global ordering across concurrent finalizations means no two
// goroutines can hold the same two locks in opposite order).
func (s *Service) lockSKUs(storeID string, skus []string) func() {
	sort.Strings(skus)
	unlocks := make([]func(), 0, len(skus))
	for _, sku := range skus {
		sku := sku
		done := make(chan struct{})
		// Use the inventory store's existing per-SKU mutex via WithSKULock.
		// We invert "lock → fn → unlock" into "lock; defer unlock" by
		// running a goroutine that holds the lock until told to release.
		go func() {
			_ = s.inv.WithSKULock(storeID, sku, func() error {
				<-done
				return nil
			})
		}()
		unlocks = append(unlocks, func() { close(done) })
	}
	return func() {
		for _, u := range unlocks {
			u()
		}
	}
}

// --- pure helpers ---

func uniqueSKUs(lines []SaleLine) []string {
	seen := make(map[string]struct{}, len(lines))
	out := make([]string, 0, len(lines))
	for _, l := range lines {
		if _, ok := seen[l.SKU]; ok {
			continue
		}
		seen[l.SKU] = struct{}{}
		out = append(out, l.SKU)
	}
	return out
}

func toProtoMoney(m payments.Money) *posv1.Money {
	return &posv1.Money{
		CurrencyCode: m.CurrencyCode,
		Units:        m.Units,
		Nanos:        m.Nanos,
	}
}

func orZeroMoney(m payments.Money, currency string) payments.Money {
	if m.CurrencyCode == "" {
		return payments.Money{CurrencyCode: currency}
	}
	return m
}

func toComputeLines(lines []SaleLine) []tax.ComputeLine {
	out := make([]tax.ComputeLine, 0, len(lines))
	for _, l := range lines {
		out = append(out, tax.ComputeLine{
			SKU:           l.SKU,
			TaxCategoryID: l.TaxCategoryID,
			LineTotal:     l.LineTotal,
			Quantity:      l.Quantity,
		})
	}
	return out
}

func toProtoLines(lines []SaleLine, lineTax []tax.LineTax) []*posv1.SaleLine {
	out := make([]*posv1.SaleLine, 0, len(lines))
	for i, l := range lines {
		sl := &posv1.SaleLine{
			LineId:        l.LineID.String(),
			Sku:           l.SKU,
			Description:   l.Description,
			Quantity:      l.Quantity,
			UnitPrice:     toProtoMoney(l.UnitPrice),
			LineTotal:     toProtoMoney(l.LineTotal),
			TaxCategoryId: l.TaxCategoryID,
		}
		// lineTax may be empty (no tax computed); the engine guarantees
		// 1-to-1 alignment with `lines` when populated, so guard on len.
		if i < len(lineTax) {
			sl.LineTax = toProtoMoney(lineTax[i].Tax)
		}
		out = append(out, sl)
	}
	return out
}

func formatMoney(m payments.Money) string {
	return fmt.Sprintf("%s{%d.%09d}", m.CurrencyCode, m.Units, m.Nanos)
}
