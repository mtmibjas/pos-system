package refunds

import (
	"errors"
	"fmt"
)

// Sentinel errors surfaced by the package.
var (
	// ErrNotFound: row not found in voids or refunds.
	ErrNotFound = errors.New("refunds: not found")

	// ErrAlreadyVoided: a void already exists for this sale_id. Voids are
	// 1:1 with sales (UNIQUE sale_id in sale_voids).
	ErrAlreadyVoided = errors.New("refunds: sale already voided")

	// ErrSaleAlreadyRefunded: a refund was already issued in such a way
	// that the line in question is fully refunded — see ErrOverRefund for
	// the per-line variant.
	ErrSaleAlreadyRefunded = errors.New("refunds: sale already fully refunded")

	// ErrCannotRefundVoided: cannot refund a sale that has been voided.
	ErrCannotRefundVoided = errors.New("refunds: cannot refund a voided sale")

	// ErrCannotVoidRefunded: cannot void a sale that has any refunds
	// against it. Refund first, then a void no longer applies.
	ErrCannotVoidRefunded = errors.New("refunds: cannot void a sale with refunds")

	// ErrEmptyLines: at least one line is required on a refund.
	ErrEmptyLines = errors.New("refunds: at least one line is required")

	// ErrTenderMismatch: refund tender method does not match the original
	// payment's method (e.g. trying to refund a card sale as cash). The
	// rule is enforced because card-network rules effectively require
	// refunds to settle back to the original card.
	ErrTenderMismatch = errors.New("refunds: refund tender method does not match original")

	// ErrTenderSumMismatch: sum of refund tenders does not equal the
	// refund grand total.
	ErrTenderSumMismatch = errors.New("refunds: tender sum does not equal grand total")

	// ErrVoidWindowClosed: void was attempted outside the same-shift
	// window. Use a refund instead.
	ErrVoidWindowClosed = errors.New("refunds: void window closed; use refund")
)

// ErrOverRefund is returned when a refund line would push the cumulative
// refunded quantity for the (sale, sale_line_id) above the original sold
// quantity.
type ErrOverRefund struct {
	SaleLineID   string
	SKU          string
	SoldQuantity int64
	AlreadyQty   int64
	RequestedQty int64
}

func (e *ErrOverRefund) Error() string {
	return fmt.Sprintf(
		"refunds: over-refund on line %s (sku=%s): sold=%d already_refunded=%d requested=%d",
		e.SaleLineID, e.SKU, e.SoldQuantity, e.AlreadyQty, e.RequestedQty,
	)
}

// ErrUnknownSaleLine is returned when a refund references a sale_line_id
// that doesn't exist on the original sale.
type ErrUnknownSaleLine struct {
	SaleLineID string
}

func (e *ErrUnknownSaleLine) Error() string {
	return fmt.Sprintf("refunds: sale line %s not found on original sale", e.SaleLineID)
}
