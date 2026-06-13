// Service.Void and Service.Refund are the canonical entry points for
// reversing a sale. They mirror sales.Service.Finalize in structure:
// validate, take per-SKU locks, then write the atomic batch of opslog
// events + ledger rows + projection rows inside one txn.Apply under one
// fresh BatchID.
//
// Why both live here: voids and refunds share enough plumbing
// (lookup-original, restock helpers, payments-reversal pairing,
// idempotency lookup, sale-state guards) that splitting them would
// duplicate too much; the divergence is mostly in their entry
// validation.
package refunds

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
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/txn"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
)

// Notifier wakes the sync worker after a successful commit. Mirrors the
// sales.Notifier shape without importing the sales package (refunds is
// a sibling, not a child).
type Notifier interface {
	Notify()
}

// NoopNotifier is a safe default for tests / dry runs.
type NoopNotifier struct{}

func (NoopNotifier) Notify() {}

// Service is the void/refund producer. One per local-store-server.
type Service struct {
	db         *sql.DB
	ops        *opslog.Store
	inv        *inventory.Store
	pays       *payments.Store
	invs       *invoices.Store
	refs       *Store
	tax        *tax.Engine
	clk        *clock.Lamport
	notifier   Notifier
	publisher  hub.Publisher
	nodeID     string
	tenantID   string
	voidWindow time.Duration
}

// Config groups constructor inputs. VoidWindow is required and bounds the
// time between original sale and a same-shift void; refunds beyond that
// must go through Refund.
type Config struct {
	DB         *sql.DB
	Ops        *opslog.Store
	Inv        *inventory.Store
	Pays       *payments.Store
	Invoices   *invoices.Store
	Refunds    *Store
	Tax        *tax.Engine
	Clock      *clock.Lamport
	Notifier   Notifier
	Publisher  hub.Publisher // nil → hub.NopPublisher; broadcasts every committed event post-commit
	NodeID     string
	TenantID   string
	VoidWindow time.Duration
}

func NewService(c Config) (*Service, error) {
	switch {
	case c.DB == nil:
		return nil, errors.New("refunds: Config.DB is required")
	case c.Ops == nil:
		return nil, errors.New("refunds: Config.Ops is required")
	case c.Inv == nil:
		return nil, errors.New("refunds: Config.Inv is required")
	case c.Pays == nil:
		return nil, errors.New("refunds: Config.Pays is required")
	case c.Invoices == nil:
		return nil, errors.New("refunds: Config.Invoices is required")
	case c.Refunds == nil:
		return nil, errors.New("refunds: Config.Refunds is required")
	case c.Tax == nil:
		return nil, errors.New("refunds: Config.Tax is required")
	case c.Clock == nil:
		return nil, errors.New("refunds: Config.Clock is required")
	case c.NodeID == "":
		return nil, errors.New("refunds: Config.NodeID is required")
	case c.TenantID == "":
		return nil, errors.New("refunds: Config.TenantID is required")
	case c.VoidWindow <= 0:
		return nil, errors.New("refunds: Config.VoidWindow must be positive")
	}
	if c.Notifier == nil {
		c.Notifier = NoopNotifier{}
	}
	if c.Publisher == nil {
		c.Publisher = hub.NopPublisher{}
	}
	return &Service{
		db:         c.DB,
		ops:        c.Ops,
		inv:        c.Inv,
		pays:       c.Pays,
		invs:       c.Invoices,
		refs:       c.Refunds,
		tax:        c.Tax,
		clk:        c.Clock,
		notifier:   c.Notifier,
		publisher:  c.Publisher,
		nodeID:     c.NodeID,
		tenantID:   c.TenantID,
		voidWindow: c.VoidWindow,
	}, nil
}

// --- Void ----------------------------------------------------------------

// VoidRequest is the in-process input to Void.
type VoidRequest struct {
	VoidID     uuid.UUID
	SaleID     uuid.UUID
	StoreID    string
	CounterID  string
	CashierID  string
	Reason     string
	OccurredAt time.Time
}

// VoidResponse reports the outcome of Void.
type VoidResponse struct {
	VoidID     uuid.UUID
	BatchID    uuid.UUID
	Lamport    uint64
	Void       Void
	Idempotent bool // true if a void with the same VoidID was already committed
}

// Void fully reverses a sale issued within the same-shift window.
// Restores inventory for every original line and reverses every original
// payment. Hard rule: not allowed if any refund already exists against
// this sale (use Refund instead).
func (s *Service) Void(ctx context.Context, req VoidRequest) (VoidResponse, error) {
	if err := s.validateVoidReq(req); err != nil {
		return VoidResponse{}, err
	}

	// Idempotency: VoidID is the operation_id of the SaleVoided op. If we
	// already wrote it, return the prior outcome rather than producing a
	// duplicate set of compensating events.
	if prior, ok, err := s.lookupPriorVoid(ctx, req.VoidID); err != nil {
		return VoidResponse{}, err
	} else if ok {
		return prior, nil
	}

	// Load original sale state.
	sale, originalLines, err := s.loadOriginalSale(ctx, req.SaleID)
	if err != nil {
		return VoidResponse{}, err
	}
	invoice, err := s.invs.GetBySale(ctx, req.SaleID)
	if err != nil {
		return VoidResponse{}, fmt.Errorf("refunds: lookup invoice for sale %s: %w", req.SaleID, err)
	}

	// Sale-state guards.
	if _, err := s.refs.GetVoidBySale(ctx, req.SaleID); err == nil {
		return VoidResponse{}, ErrAlreadyVoided
	} else if !errors.Is(err, ErrNotFound) {
		return VoidResponse{}, fmt.Errorf("refunds: existing-void lookup: %w", err)
	}
	priorRefunds, err := s.refs.ListRefundsBySale(ctx, req.SaleID)
	if err != nil {
		return VoidResponse{}, err
	}
	if len(priorRefunds) > 0 {
		return VoidResponse{}, ErrCannotVoidRefunded
	}

	// Same-shift window.
	if req.OccurredAt.Sub(invoice.FinalizedAt) > s.voidWindow {
		return VoidResponse{}, fmt.Errorf("%w (window=%s, sale finalized at %s, void at %s)",
			ErrVoidWindowClosed, s.voidWindow, invoice.FinalizedAt, req.OccurredAt)
	}

	// Load original payments (we'll mirror each one with a negative,
	// parent-linked reversal). ListForSale returns only positive
	// payments — refunds are filtered by the caller-defined query — so
	// we don't have to worry about voiding a sale that's already been
	// partially refunded into negatives (which the guard above also
	// blocks).
	originalPays, err := s.pays.ListForSale(ctx, req.SaleID)
	if err != nil {
		return VoidResponse{}, fmt.Errorf("refunds: list payments: %w", err)
	}
	positivePays := make([]payments.Payment, 0, len(originalPays))
	for _, p := range originalPays {
		if p.Amount.Sign() > 0 {
			positivePays = append(positivePays, p)
		}
	}

	// Build the SaleVoided proto once — used as both the opslog payload
	// and the void-row snapshot so the two never disagree.
	voidProto := &posv1.SaleVoided{
		VoidId:        req.VoidID.String(),
		SaleId:        req.SaleID.String(),
		InvoiceNumber: invoice.InvoiceNumber,
		StoreId:       &posv1.StoreId{Value: req.StoreID},
		CounterId:     &posv1.CounterId{Value: req.CounterID},
		CashierId:     &posv1.UserId{Value: req.CashierID},
		Reason:        req.Reason,
	}

	batchID := uuid.New()
	lamport, err := s.clk.Next(ctx)
	if err != nil {
		return VoidResponse{}, fmt.Errorf("refunds: lamport next: %w", err)
	}

	// Lock per-SKU like Finalize does to keep inventory mutations
	// serialized when multiple voids/refunds touch the same SKU.
	unlock := s.lockSKUs(req.StoreID, uniqueSKUsFromOriginal(originalLines))
	defer unlock()

	var stored Void
	err = txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		// 1) SaleVoided op.
		if err := s.packAndInsertOp(ctx, tx, opCommon{
			operationID:   req.VoidID,
			operationType: "sale_voided",
			entityType:    "sale",
			entityID:      req.SaleID.String(),
			payload:       voidProto,
			batchID:       batchID,
			lamport:       lamport,
			occurredAt:    req.OccurredAt,
		}); err != nil {
			return fmt.Errorf("sale_voided: %w", err)
		}
		// 2) Restore inventory for every original line (full void = full
		// restock; per-line restock flag is a refund-only concept).
		for _, ln := range originalLines {
			if err := s.restoreInventory(ctx, tx, req.StoreID, req.CounterID, ln.Sku, ln.Quantity,
				inventory.ReasonVoid, "sale_void", req.VoidID.String(),
				batchID, lamport, req.OccurredAt); err != nil {
				return fmt.Errorf("restock sku=%s: %w", ln.Sku, err)
			}
		}
		// 3) Mirror each original payment with a reversal.
		for _, op := range positivePays {
			if err := s.writePaymentReversal(ctx, tx, paymentReversal{
				saleID:            req.SaleID,
				originalPaymentID: op.PaymentID,
				method:            op.Method,
				amount:            op.Amount,      // magnitude
				reference:         op.Reference,
				batchID:           batchID,
				lamport:           lamport,
				occurredAt:        req.OccurredAt,
			}); err != nil {
				return fmt.Errorf("reverse payment %s: %w", op.PaymentID, err)
			}
		}
		// 4) Void projection row.
		v, ierr := s.refs.IssueVoidTx(ctx, tx, IssueVoidRequest{
			VoidID:    req.VoidID,
			SaleID:    req.SaleID,
			InvoiceID: invoice.InvoiceID,
			StoreID:   req.StoreID,
			CounterID: req.CounterID,
			CashierID: req.CashierID,
			Reason:    req.Reason,
			Snapshot:  voidProto,
			VoidedAt:  req.OccurredAt,
		})
		if ierr != nil {
			return fmt.Errorf("void row: %w", ierr)
		}
		stored = v
		return nil
	})
	if err != nil {
		return VoidResponse{}, err
	}
	_ = sale // currently no further use; kept for future fields
	s.notifier.Notify()
	// Fan committed events out to realtime subscribers (Phase 4 slice 4.2).
	s.broadcastBatch(ctx, batchID)
	return VoidResponse{
		VoidID:  req.VoidID,
		BatchID: batchID,
		Lamport: lamport,
		Void:    stored,
	}, nil
}

// --- Refund --------------------------------------------------------------

// RefundLineRequest is one line of a refund.
//
// TaxCategoryID is required: the tax engine re-runs against current rates
// to produce the authoritative split. Limitation: if the category's rate
// has changed between original sale and refund, refund tax will reflect
// the new rate — a known constraint addressed when per-line tax breakdown
// is added to SaleCreated.
type RefundLineRequest struct {
	SaleLineID    uuid.UUID
	SKU           string
	Quantity      int64
	Restock       bool
	UnitPrice     payments.Money
	LineTotal     payments.Money // = UnitPrice * Quantity
	TaxCategoryID string
}

// RefundTenderRequest is one refund tender. Method must match the method
// of the OriginalPaymentID; that's how we enforce card→card / cash→cash.
type RefundTenderRequest struct {
	RefundPaymentID   uuid.UUID
	OriginalPaymentID uuid.UUID
	Method            payments.Method
	Amount            payments.Money // positive magnitude (engine flips sign for ledger)
	Reference         string
}

// RefundRequest is the in-process input to Refund.
type RefundRequest struct {
	RefundID   uuid.UUID
	SaleID     uuid.UUID
	StoreID    string
	CounterID  string
	CashierID  string
	Reason     string
	OccurredAt time.Time
	Lines      []RefundLineRequest
	Tenders    []RefundTenderRequest
}

// RefundResponse reports the outcome of Refund.
type RefundResponse struct {
	RefundID   uuid.UUID
	BatchID    uuid.UUID
	Lamport    uint64
	Refund     Refund
	Idempotent bool
}

// Refund issues a (partial or full) refund against a finalized sale.
// Server-authoritative on tax: re-runs the tax engine against the refund
// lines and uses its output as Subtotal/TaxTotal/GrandTotal. Validates
// per-line over-refund, tender-method-matches-original, and
// Σ tenders = grand.
func (s *Service) Refund(ctx context.Context, req RefundRequest) (RefundResponse, error) {
	if err := s.validateRefundReq(req); err != nil {
		return RefundResponse{}, err
	}

	// Idempotency on RefundID == operation_id.
	if prior, ok, err := s.lookupPriorRefund(ctx, req.RefundID); err != nil {
		return RefundResponse{}, err
	} else if ok {
		return prior, nil
	}

	// Load original sale + payments.
	_, originalLines, err := s.loadOriginalSale(ctx, req.SaleID)
	if err != nil {
		return RefundResponse{}, err
	}
	invoice, err := s.invs.GetBySale(ctx, req.SaleID)
	if err != nil {
		return RefundResponse{}, fmt.Errorf("refunds: lookup invoice for sale %s: %w", req.SaleID, err)
	}

	// Sale-state guards.
	if _, err := s.refs.GetVoidBySale(ctx, req.SaleID); err == nil {
		return RefundResponse{}, ErrCannotRefundVoided
	} else if !errors.Is(err, ErrNotFound) {
		return RefundResponse{}, fmt.Errorf("refunds: existing-void lookup: %w", err)
	}

	// Per-line over-refund check.
	originalByLineID, err := indexOriginalLines(originalLines, req.Lines)
	if err != nil {
		return RefundResponse{}, err
	}
	alreadyRefunded, err := s.refs.SumRefundedQty(ctx, req.SaleID)
	if err != nil {
		return RefundResponse{}, err
	}
	for _, ln := range req.Lines {
		orig := originalByLineID[ln.SaleLineID]
		sold := orig.Quantity
		already := alreadyRefunded[ln.SaleLineID]
		if already+ln.Quantity > sold {
			return RefundResponse{}, &ErrOverRefund{
				SaleLineID:   ln.SaleLineID.String(),
				SKU:          ln.SKU,
				SoldQuantity: sold,
				AlreadyQty:   already,
				RequestedQty: ln.Quantity,
			}
		}
		// Verify UnitPrice/LineTotal match the original to prevent caller
		// drift on the magnitude being refunded.
		if !ln.UnitPrice.Equal(orig.UnitPrice) {
			return RefundResponse{}, fmt.Errorf(
				"refunds: line %s UnitPrice mismatch original (%v vs %v)",
				ln.SaleLineID, ln.UnitPrice, orig.UnitPrice)
		}
	}

	// Tender method matching: each refund tender must reference an
	// existing original payment with the same method.
	originalPays, err := s.pays.ListForSale(ctx, req.SaleID)
	if err != nil {
		return RefundResponse{}, fmt.Errorf("refunds: list payments: %w", err)
	}
	origByID := make(map[uuid.UUID]payments.Payment, len(originalPays))
	for _, p := range originalPays {
		origByID[p.PaymentID] = p
	}
	for _, t := range req.Tenders {
		orig, ok := origByID[t.OriginalPaymentID]
		if !ok {
			return RefundResponse{}, fmt.Errorf(
				"refunds: tender references unknown original payment %s", t.OriginalPaymentID)
		}
		if orig.Method != t.Method {
			return RefundResponse{}, fmt.Errorf(
				"%w: tender method %q does not match original %q",
				ErrTenderMismatch, t.Method, orig.Method)
		}
	}

	// Tax recompute (server-authoritative).
	taxResp, err := s.tax.Compute(ctx, tax.ComputeRequest{
		TenantID:   s.tenantID,
		StoreID:    req.StoreID,
		Lines:      toComputeLines(req.Lines),
		OccurredAt: req.OccurredAt,
	})
	if err != nil {
		return RefundResponse{}, fmt.Errorf("refunds: tax compute: %w", err)
	}

	// Tender sum vs computed grand.
	currency := taxResp.GrandTotal.CurrencyCode
	if err := validateTenderSumRefund(currency, req.Tenders, taxResp.GrandTotal); err != nil {
		return RefundResponse{}, err
	}

	// Build the SaleRefunded proto once.
	refundProto := buildSaleRefunded(req, invoice, taxResp)

	batchID := uuid.New()
	lamport, err := s.clk.Next(ctx)
	if err != nil {
		return RefundResponse{}, fmt.Errorf("refunds: lamport next: %w", err)
	}

	unlock := s.lockSKUs(req.StoreID, uniqueSKUsFromRefund(req.Lines))
	defer unlock()

	var stored Refund
	err = txn.Apply(ctx, s.db, func(tx *sql.Tx) error {
		// 1) SaleRefunded op.
		if err := s.packAndInsertOp(ctx, tx, opCommon{
			operationID:   req.RefundID,
			operationType: "sale_refunded",
			entityType:    "sale",
			entityID:      req.SaleID.String(),
			payload:       refundProto,
			batchID:       batchID,
			lamport:       lamport,
			occurredAt:    req.OccurredAt,
		}); err != nil {
			return fmt.Errorf("sale_refunded: %w", err)
		}
		// 2) Per-line inventory restore (only when Restock=true).
		for _, ln := range req.Lines {
			if !ln.Restock {
				continue
			}
			if err := s.restoreInventory(ctx, tx, req.StoreID, req.CounterID, ln.SKU, ln.Quantity,
				inventory.ReasonRefund, "sale_refund", req.RefundID.String(),
				batchID, lamport, req.OccurredAt); err != nil {
				return fmt.Errorf("restock sku=%s: %w", ln.SKU, err)
			}
		}
		// 3) Refund tenders (one negative payment per refund tender).
		for _, t := range req.Tenders {
			if err := s.writePaymentReversalWithID(ctx, tx, paymentReversal{
				refundPaymentID:   t.RefundPaymentID,
				saleID:            req.SaleID,
				originalPaymentID: t.OriginalPaymentID,
				method:            t.Method,
				amount:            t.Amount,
				reference:         t.Reference,
				batchID:           batchID,
				lamport:           lamport,
				occurredAt:        req.OccurredAt,
			}); err != nil {
				return fmt.Errorf("refund tender %s: %w", t.RefundPaymentID, err)
			}
		}
		// 4) Refund projection row + lines.
		modelLines := toModelRefundLines(req.RefundID, req.Lines)
		r, ierr := s.refs.IssueRefundTx(ctx, tx, IssueRefundRequest{
			RefundID:   req.RefundID,
			SaleID:     req.SaleID,
			InvoiceID:  invoice.InvoiceID,
			StoreID:    req.StoreID,
			CounterID:  req.CounterID,
			CashierID:  req.CashierID,
			Reason:     req.Reason,
			Subtotal:   taxResp.Subtotal,
			TaxTotal:   taxResp.TaxTotal,
			GrandTotal: taxResp.GrandTotal,
			Lines:      modelLines,
			Snapshot:   refundProto,
			RefundedAt: req.OccurredAt,
		})
		if ierr != nil {
			return fmt.Errorf("refund row: %w", ierr)
		}
		stored = r
		return nil
	})
	if err != nil {
		return RefundResponse{}, err
	}
	s.notifier.Notify()
	// Fan committed events out to realtime subscribers (Phase 4 slice 4.2).
	s.broadcastBatch(ctx, batchID)
	return RefundResponse{
		RefundID: req.RefundID,
		BatchID:  batchID,
		Lamport:  lamport,
		Refund:   stored,
	}, nil
}

// broadcastBatch reads every operation tagged with batchID from opslog,
// unpacks each payload back into its EventEnvelope, and publishes to the
// hub. Best-effort and post-commit only: opslog is the durable record;
// dropped broadcasts are recovered by 4.4's reconnect-with-last-seen.
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

// --- internals: validation -----------------------------------------------

func (s *Service) validateVoidReq(req VoidRequest) error {
	switch {
	case req.VoidID == uuid.Nil:
		return errors.New("refunds: VoidID is required")
	case req.SaleID == uuid.Nil:
		return errors.New("refunds: SaleID is required")
	case req.StoreID == "":
		return errors.New("refunds: StoreID is required")
	case req.OccurredAt.IsZero():
		return errors.New("refunds: OccurredAt is required")
	}
	return nil
}

func (s *Service) validateRefundReq(req RefundRequest) error {
	switch {
	case req.RefundID == uuid.Nil:
		return errors.New("refunds: RefundID is required")
	case req.SaleID == uuid.Nil:
		return errors.New("refunds: SaleID is required")
	case req.StoreID == "":
		return errors.New("refunds: StoreID is required")
	case req.OccurredAt.IsZero():
		return errors.New("refunds: OccurredAt is required")
	case len(req.Lines) == 0:
		return ErrEmptyLines
	case len(req.Tenders) == 0:
		return errors.New("refunds: at least one tender is required")
	}
	currency := req.Lines[0].LineTotal.CurrencyCode
	if currency == "" {
		return errors.New("refunds: line currency is required")
	}
	for _, ln := range req.Lines {
		if ln.SaleLineID == uuid.Nil {
			return errors.New("refunds: line SaleLineID is required")
		}
		if ln.Quantity <= 0 {
			return errors.New("refunds: line quantity must be positive")
		}
		if ln.LineTotal.CurrencyCode != currency || ln.UnitPrice.CurrencyCode != currency {
			return errors.New("refunds: mixed currencies across lines")
		}
		expected, err := ln.UnitPrice.Mul(ln.Quantity)
		if err != nil {
			return fmt.Errorf("refunds: line %s: %w", ln.SKU, err)
		}
		if !expected.Equal(ln.LineTotal) {
			return fmt.Errorf("refunds: line %s LineTotal %v ≠ UnitPrice*Qty %v",
				ln.SKU, ln.LineTotal, expected)
		}
	}
	for _, t := range req.Tenders {
		if t.RefundPaymentID == uuid.Nil {
			return errors.New("refunds: RefundPaymentID is required")
		}
		if t.OriginalPaymentID == uuid.Nil {
			return errors.New("refunds: OriginalPaymentID is required")
		}
		if t.Method == "" {
			return errors.New("refunds: tender Method is required")
		}
		if t.Amount.Sign() <= 0 {
			return errors.New("refunds: tender Amount must be positive (magnitude)")
		}
		if t.Amount.CurrencyCode != currency {
			return errors.New("refunds: tender currency mismatch")
		}
	}
	return nil
}

// --- internals: lookups --------------------------------------------------

func (s *Service) lookupPriorVoid(ctx context.Context, voidID uuid.UUID) (VoidResponse, bool, error) {
	op, err := s.ops.Get(ctx, voidID)
	if errors.Is(err, opslog.ErrNotFound) {
		return VoidResponse{}, false, nil
	}
	if err != nil {
		return VoidResponse{}, false, fmt.Errorf("refunds: void idempotency lookup: %w", err)
	}
	if op.OperationType != "sale_voided" {
		return VoidResponse{}, false, fmt.Errorf(
			"refunds: VoidID %s collides with existing op of type %q", voidID, op.OperationType)
	}
	// Find the projection row to return the full Void.
	saleID, err := uuid.Parse(op.EntityID)
	if err != nil {
		return VoidResponse{}, false, fmt.Errorf("refunds: parse entity_id: %w", err)
	}
	v, err := s.refs.GetVoidBySale(ctx, saleID)
	if err != nil {
		return VoidResponse{}, false, fmt.Errorf("refunds: load prior void: %w", err)
	}
	return VoidResponse{
		VoidID:     voidID,
		BatchID:    op.BatchID,
		Lamport:    op.Lamport,
		Void:       v,
		Idempotent: true,
	}, true, nil
}

func (s *Service) lookupPriorRefund(ctx context.Context, refundID uuid.UUID) (RefundResponse, bool, error) {
	op, err := s.ops.Get(ctx, refundID)
	if errors.Is(err, opslog.ErrNotFound) {
		return RefundResponse{}, false, nil
	}
	if err != nil {
		return RefundResponse{}, false, fmt.Errorf("refunds: refund idempotency lookup: %w", err)
	}
	if op.OperationType != "sale_refunded" {
		return RefundResponse{}, false, fmt.Errorf(
			"refunds: RefundID %s collides with existing op of type %q", refundID, op.OperationType)
	}
	saleID, err := uuid.Parse(op.EntityID)
	if err != nil {
		return RefundResponse{}, false, fmt.Errorf("refunds: parse entity_id: %w", err)
	}
	all, err := s.refs.ListRefundsBySale(ctx, saleID)
	if err != nil {
		return RefundResponse{}, false, err
	}
	for _, r := range all {
		if r.RefundID == refundID {
			return RefundResponse{
				RefundID:   refundID,
				BatchID:    op.BatchID,
				Lamport:    op.Lamport,
				Refund:     r,
				Idempotent: true,
			}, true, nil
		}
	}
	return RefundResponse{}, false, fmt.Errorf("refunds: opslog has refund %s but row missing", refundID)
}

// loadOriginalSale fetches the SaleCreated op and unpacks its payload to
// recover the original line items. The proto bytes ARE the source of
// truth for what was sold.
func (s *Service) loadOriginalSale(ctx context.Context, saleID uuid.UUID) (*posv1.SaleCreated, []*posv1.SaleLine, error) {
	op, err := s.ops.Get(ctx, saleID)
	if errors.Is(err, opslog.ErrNotFound) {
		return nil, nil, fmt.Errorf("refunds: original sale %s not found", saleID)
	}
	if err != nil {
		return nil, nil, fmt.Errorf("refunds: load original sale: %w", err)
	}
	if op.OperationType != "sale_created" {
		return nil, nil, fmt.Errorf("refunds: SaleID %s is not a sale_created (type=%q)", saleID, op.OperationType)
	}
	_, inner, err := events.Unpack(op.Payload)
	if err != nil {
		return nil, nil, fmt.Errorf("refunds: unpack original sale: %w", err)
	}
	sale, ok := inner.(*posv1.SaleCreated)
	if !ok {
		return nil, nil, fmt.Errorf("refunds: original op payload is %T, expected *SaleCreated", inner)
	}
	return sale, sale.Lines, nil
}

// --- internals: write helpers --------------------------------------------

// paymentReversal carries fields common to void- and refund-side reversal
// inserts. RefundPaymentID is zero-valued on the void path (auto-assigned)
// and caller-supplied on the refund path.
type paymentReversal struct {
	refundPaymentID   uuid.UUID
	saleID            uuid.UUID
	originalPaymentID uuid.UUID
	method            payments.Method
	amount            payments.Money // positive magnitude; helper flips sign
	reference         string
	batchID           uuid.UUID
	lamport           uint64
	occurredAt        time.Time
}

// writePaymentReversal: void-side. Generates the refund payment id.
func (s *Service) writePaymentReversal(ctx context.Context, tx *sql.Tx, p paymentReversal) error {
	p.refundPaymentID = uuid.New()
	return s.writePaymentReversalWithID(ctx, tx, p)
}

// writePaymentReversalWithID handles the common reversal write — refund
// row in payments ledger + corresponding PaymentRefunded op.
func (s *Service) writePaymentReversalWithID(ctx context.Context, tx *sql.Tx, p paymentReversal) error {
	neg := p.amount.Neg()
	refunded := &posv1.PaymentRefunded{
		RefundId:          p.refundPaymentID.String(),
		OriginalPaymentId: p.originalPaymentID.String(),
		Amount:            toProtoMoney(p.amount), // event carries magnitude; ledger row is signed
		Reason:            "void_or_refund",
	}
	if err := s.packAndInsertOp(ctx, tx, opCommon{
		operationID:   p.refundPaymentID,
		operationType: "payment_refunded",
		entityType:    "payment",
		entityID:      p.refundPaymentID.String(),
		payload:       refunded,
		batchID:       p.batchID,
		lamport:       p.lamport,
		occurredAt:    p.occurredAt,
	}); err != nil {
		return err
	}
	_, _, err := s.pays.InsertTx(ctx, tx, payments.Payment{
		PaymentID:       p.refundPaymentID,
		SaleID:          p.saleID,
		Method:          p.method,
		Amount:          neg,
		Reference:       p.reference,
		ParentPaymentID: p.originalPaymentID,
		CreatedAt:       p.occurredAt,
	})
	return err
}

// restoreInventory writes an InventoryAdjusted op + inventory ledger row
// for a positive-delta movement.
func (s *Service) restoreInventory(
	ctx context.Context, tx *sql.Tx,
	storeID, counterID, sku string, qty int64,
	reason inventory.Reason, refType, refID string,
	batchID uuid.UUID, lamport uint64, occurredAt time.Time,
) error {
	movementID := uuid.New()
	adjusted := &posv1.InventoryAdjusted{
		Sku:    sku,
		Delta:  qty, // positive — restock
		Reason: string(reason),
		RefId:  refID,
	}
	if err := s.packAndInsertOp(ctx, tx, opCommon{
		operationID:   movementID,
		operationType: "inventory_adjusted",
		entityType:    "inventory",
		entityID:      sku,
		payload:       adjusted,
		batchID:       batchID,
		lamport:       lamport,
		occurredAt:    occurredAt,
	}); err != nil {
		return err
	}
	return s.inv.AppendTx(ctx, tx, inventory.Movement{
		MovementID:   movementID,
		SKU:          sku,
		StoreID:      storeID,
		CounterID:    counterID,
		Delta:        qty,
		Reason:       reason,
		RefType:      refType,
		RefID:        refID,
		OccurredAt:   occurredAt,
		Lamport:      lamport,
		OriginNodeID: s.nodeID,
	})
}

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

// lockSKUs mirrors sales.Service.lockSKUs: per-SKU mutexes acquired in
// sorted order to make deadlocks impossible across concurrent refunds /
// finalizations touching overlapping SKU sets.
func (s *Service) lockSKUs(storeID string, skus []string) func() {
	sort.Strings(skus)
	unlocks := make([]func(), 0, len(skus))
	for _, sku := range skus {
		sku := sku
		done := make(chan struct{})
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

// --- pure helpers --------------------------------------------------------

func uniqueSKUsFromOriginal(lines []*posv1.SaleLine) []string {
	seen := make(map[string]struct{}, len(lines))
	out := make([]string, 0, len(lines))
	for _, l := range lines {
		if _, ok := seen[l.Sku]; ok {
			continue
		}
		seen[l.Sku] = struct{}{}
		out = append(out, l.Sku)
	}
	return out
}

func uniqueSKUsFromRefund(lines []RefundLineRequest) []string {
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

// indexOriginalLines builds a SaleLineID-keyed view of the original sale
// lines (parsed from the snapshot proto) and validates that every refund
// line references a known original.
func indexOriginalLines(originalLines []*posv1.SaleLine, refundLines []RefundLineRequest) (map[uuid.UUID]originalLineView, error) {
	// SaleCreated's SaleLine doesn't carry the LineID directly — by
	// design, the wire payload is the public projection of the sale.
	// We need a way to map RefundLine.SaleLineID back to an original.
	// The current SaleCreated proto only ships sku + qty + unit_price.
	// So our matching key inside this slice is (sku, unit_price,
	// remaining_qty) by SKU; we treat each unique SKU on the original
	// as a single "bucket" the refund can draw from. The refund-line
	// SaleLineID is a caller-supplied identifier we persist for later
	// over-refund accounting but do NOT rely on for lookup here.
	bucketsBySKU := map[string]*originalLineView{}
	for _, l := range originalLines {
		v, ok := bucketsBySKU[l.Sku]
		if !ok {
			bucketsBySKU[l.Sku] = &originalLineView{
				SKU:       l.Sku,
				Quantity:  l.Quantity,
				UnitPrice: protoMoneyToPayments(l.UnitPrice),
			}
			continue
		}
		// Aggregate quantity when the same SKU appears on multiple lines.
		v.Quantity += l.Quantity
	}
	out := make(map[uuid.UUID]originalLineView, len(refundLines))
	for _, rl := range refundLines {
		bucket, ok := bucketsBySKU[rl.SKU]
		if !ok {
			return nil, &ErrUnknownSaleLine{SaleLineID: rl.SaleLineID.String()}
		}
		out[rl.SaleLineID] = *bucket
	}
	return out, nil
}

// originalLineView is the per-refund-line lookup result: how much of this
// SKU was sold (aggregated if the SKU appeared on multiple original lines),
// at what unit price.
type originalLineView struct {
	SKU       string
	Quantity  int64
	UnitPrice payments.Money
}

func toComputeLines(lines []RefundLineRequest) []tax.ComputeLine {
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

func toModelRefundLines(refundID uuid.UUID, lines []RefundLineRequest) []RefundLine {
	out := make([]RefundLine, 0, len(lines))
	for _, l := range lines {
		out = append(out, RefundLine{
			RefundID:   refundID,
			SaleLineID: l.SaleLineID,
			SKU:        l.SKU,
			Quantity:   l.Quantity,
			Restock:    l.Restock,
			UnitPrice:  l.UnitPrice,
			LineTotal:  l.LineTotal,
		})
	}
	return out
}

func buildSaleRefunded(req RefundRequest, invoice invoices.Invoice, taxResp tax.ComputeResponse) *posv1.SaleRefunded {
	lines := make([]*posv1.RefundLine, 0, len(req.Lines))
	for i, l := range req.Lines {
		rl := &posv1.RefundLine{
			SaleLineId:    l.SaleLineID.String(),
			Sku:           l.SKU,
			Quantity:      l.Quantity,
			Restock:       l.Restock,
			UnitPrice:     toProtoMoney(l.UnitPrice),
			LineTotal:     toProtoMoney(l.LineTotal),
			TaxCategoryId: l.TaxCategoryID,
		}
		// taxResp.Lines is 1-to-1 with req.Lines (engine guarantee). When
		// no tax applies, the slice may be empty; guard on len.
		if i < len(taxResp.Lines) {
			rl.LineTax = toProtoMoney(taxResp.Lines[i].Tax)
		}
		lines = append(lines, rl)
	}
	tenders := make([]*posv1.RefundTender, 0, len(req.Tenders))
	for _, t := range req.Tenders {
		tenders = append(tenders, &posv1.RefundTender{
			RefundPaymentId:    t.RefundPaymentID.String(),
			OriginalPaymentId:  t.OriginalPaymentID.String(),
			Method:             string(t.Method),
			Amount:             toProtoMoney(t.Amount),
			Reference:          t.Reference,
		})
	}
	// CreditNoteNumber is allocated inside IssueRefundTx; the snapshot we
	// build here doesn't yet know it. Leave the field empty in the proto;
	// the projection row carries the authoritative number. (If we needed
	// CN in the synced event, we'd allocate it before building proto and
	// pass it into IssueRefundTx — a refactor for later when an external
	// consumer of the event needs CN numbers.)
	return &posv1.SaleRefunded{
		RefundId:         req.RefundID.String(),
		SaleId:           req.SaleID.String(),
		CreditNoteNumber: "", // filled by projection row, see comment above
		StoreId:          &posv1.StoreId{Value: req.StoreID},
		CounterId:        &posv1.CounterId{Value: req.CounterID},
		CashierId:        &posv1.UserId{Value: req.CashierID},
		Reason:           req.Reason,
		Lines:            lines,
		Subtotal:         toProtoMoney(taxResp.Subtotal),
		TaxTotal:         toProtoMoney(taxResp.TaxTotal),
		GrandTotal:       toProtoMoney(taxResp.GrandTotal),
		Tenders:          tenders,
	}
}

func validateTenderSumRefund(currency string, tenders []RefundTenderRequest, grandTotal payments.Money) error {
	sum := payments.Money{CurrencyCode: currency}
	for _, t := range tenders {
		var err error
		sum, err = sum.Add(t.Amount)
		if err != nil {
			return fmt.Errorf("refunds: tender accum: %w", err)
		}
	}
	if !sum.Equal(grandTotal) {
		return fmt.Errorf("%w (sum=%v, grand=%v)", ErrTenderSumMismatch, sum, grandTotal)
	}
	return nil
}

func toProtoMoney(m payments.Money) *posv1.Money {
	return &posv1.Money{
		CurrencyCode: m.CurrencyCode,
		Units:        m.Units,
		Nanos:        m.Nanos,
	}
}

func protoMoneyToPayments(m *posv1.Money) payments.Money {
	if m == nil {
		return payments.Money{}
	}
	return payments.Money{
		CurrencyCode: m.CurrencyCode,
		Units:        m.Units,
		Nanos:        m.Nanos,
	}
}
