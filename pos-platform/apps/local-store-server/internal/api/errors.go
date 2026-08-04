package api

import (
	"errors"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/expenses"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/inventory"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/invoices"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/items"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/opslog"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/refunds"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/reservations"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/sales"
	"github.com/mibjas/pos-platform/apps/local-store-server/internal/tax"
)

// api-layer sentinels returned by handler-side input validation (before
// reaching the domain service).
var (
	errMissingCategory       = errors.New("api: UpsertTaxCategoryRequest.category is required")
	errMissingComponent      = errors.New("api: UpsertTaxComponentRequest.component is required")
	errComponentNotPersisted = errors.New("api: component disappeared after upsert")
)

// toConnectErr maps domain errors to Connect codes.
//
// Mapping rules:
//   - InvalidArgument: malformed input — empty IDs, currency mismatch,
//     non-positive quantities, line-total arithmetic drift.
//   - FailedPrecondition: input is well-formed but the system state forbids
//     the action — sale-state guards (already voided / refunded), over-
//     refund, void window closed, tender method mismatch, tender sum off,
//     caller totals disagree with engine.
//   - NotFound: referenced row does not exist (tax category, original sale).
//   - AlreadyExists: collision on a key that should be unique-by-construction
//     (currently unused — idempotent SaleID replay is success, not an error).
//   - Internal: anything we don't recognize. The wrapper logs the cause and
//     returns a generic message; clients should never see raw DB text.
//
// We always *wrap* the original error (connect.NewError takes an error)
// so server-side logs preserve the cause. Connect strips wrap info from
// the wire payload by default.
func toConnectErr(err error) error {
	if err == nil {
		return nil
	}
	if _, ok := err.(*connect.Error); ok {
		// Already a Connect error — pass through (e.g. Unimplemented).
		return err
	}

	// --- sales sentinels ---
	switch {
	case errors.Is(err, sales.ErrNoLines),
		errors.Is(err, sales.ErrNoTenders),
		errors.Is(err, sales.ErrEmptyTenant),
		errors.Is(err, sales.ErrCurrencyMix),
		errors.Is(err, sales.ErrNilSaleID),
		errors.Is(err, sales.ErrNonPositiveQty):
		return connect.NewError(connect.CodeInvalidArgument, err)
	}
	// Typed sales errors.
	var lineMismatch *sales.ErrLineTotalMismatch
	if errors.As(err, &lineMismatch) {
		return connect.NewError(connect.CodeInvalidArgument, err)
	}
	var grandMismatch *sales.ErrGrandTotalMismatch
	if errors.As(err, &grandMismatch) {
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}
	var totalsMismatch *sales.ErrTotalsMismatch
	if errors.As(err, &totalsMismatch) {
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}

	// --- refunds sentinels ---
	switch {
	case errors.Is(err, refunds.ErrEmptyLines):
		return connect.NewError(connect.CodeInvalidArgument, err)
	case errors.Is(err, refunds.ErrNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	case errors.Is(err, refunds.ErrAlreadyVoided),
		errors.Is(err, refunds.ErrSaleAlreadyRefunded),
		errors.Is(err, refunds.ErrCannotRefundVoided),
		errors.Is(err, refunds.ErrCannotVoidRefunded),
		errors.Is(err, refunds.ErrTenderMismatch),
		errors.Is(err, refunds.ErrTenderSumMismatch),
		errors.Is(err, refunds.ErrVoidWindowClosed):
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}
	var overRefund *refunds.ErrOverRefund
	if errors.As(err, &overRefund) {
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}
	var unknownLine *refunds.ErrUnknownSaleLine
	if errors.As(err, &unknownLine) {
		return connect.NewError(connect.CodeInvalidArgument, err)
	}

	// --- tax sentinels ---
	switch {
	case errors.Is(err, tax.ErrCategoryNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	case errors.Is(err, tax.ErrEmptyTenant),
		errors.Is(err, tax.ErrCurrencyMix):
		return connect.NewError(connect.CodeInvalidArgument, err)
	case errors.Is(err, tax.ErrOverflow):
		return connect.NewError(connect.CodeInvalidArgument, err)
	}

	// --- reservations sentinels ---
	switch {
	case errors.Is(err, reservations.ErrNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	case errors.Is(err, reservations.ErrNotActive):
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}
	var insuff *reservations.ErrInsufficientAvailable
	if errors.As(err, &insuff) {
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}

	// --- inventory sentinels ---
	var oversell *inventory.OversellError
	if errors.As(err, &oversell) {
		return connect.NewError(connect.CodeFailedPrecondition, err)
	}

	// --- items sentinels ---
	switch {
	case errors.Is(err, items.ErrItemNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	case errors.Is(err, items.ErrInvalidItem):
		return connect.NewError(connect.CodeInvalidArgument, err)
	}

	// --- expenses sentinels ---
	switch {
	case errors.Is(err, expenses.ErrInvalidExpense):
		return connect.NewError(connect.CodeInvalidArgument, err)
	}

	// --- foreign-key style lookups ---
	switch {
	case errors.Is(err, opslog.ErrNotFound),
		errors.Is(err, invoices.ErrNotFound):
		return connect.NewError(connect.CodeNotFound, err)
	}

	// Fallthrough: opaque internal error.
	return connect.NewError(connect.CodeInternal, err)
}
