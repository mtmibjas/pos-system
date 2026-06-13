// Package tax is the server-authoritative tax engine.
//
// A Category is a label assigned to SKUs ("GST-18", "EXEMPT"). Categories
// are composed of 1..N rate Components ("CGST", "SGST", "IGST", "VAT") —
// India GST's intra-state split and inter-state single-rate both fit the
// same model. Rates are basis points (10000 = 100%); no floats appear in
// tax arithmetic.
//
// Engine.Compute consumes (TaxCategoryID, LineTotal, Quantity) per line and
// returns net, tax, and a per-component breakdown — rounded so the
// breakdown sum exactly equals the per-line tax (no penny-drift on
// receipts).
//
// Use:
//
//	resp, err := engine.Compute(ctx, tax.ComputeRequest{
//	    TenantID: "tenant-A",
//	    Lines:    lines,
//	})
//	// resp.Subtotal, resp.TaxTotal, resp.GrandTotal, resp.Breakdown.
package tax

import (
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Category is a tax bucket assigned to SKUs.
type Category struct {
	ID               string
	Name             string
	TenantID         string
	PriceIncludesTax bool // gross-of-tax pricing (extract tax from line total)
	Components       []Component
	ArchivedAt       *time.Time
}

// TotalRateBP returns the sum of component basis points.
func (c Category) TotalRateBP() int64 {
	var total int64
	for _, comp := range c.Components {
		total += int64(comp.RateBP)
	}
	return total
}

// Component is one constituent of a Category (e.g. CGST 9% inside GST-18).
type Component struct {
	ID            string
	Name          string
	RateBP        int32 // basis points (10000 = 100%); validated in [0, 100000]
	SortOrder     int32
	TaxCategoryID string
}

// ComputeRequest is the input to Engine.Compute.
type ComputeRequest struct {
	TenantID   string
	StoreID    string // future: jurisdiction filtering
	Lines      []ComputeLine
	OccurredAt time.Time // future: rate effective-window lookup
}

// ComputeLine is one item in a cart from the tax engine's point of view.
//
// LineTotal is:
//   - the GROSS amount (tax-inclusive) when the line's category has
//     PriceIncludesTax = true, OR
//   - the NET amount (tax-exclusive) when PriceIncludesTax = false.
//
// The engine derives net/tax from LineTotal using the category's rule.
// Empty TaxCategoryID is treated as EXEMPT (tax = 0; net = gross = line total).
type ComputeLine struct {
	SKU           string
	TaxCategoryID string
	LineTotal     payments.Money
	Quantity      int64
}

// ComputeResponse is the engine output. Lines is 1-to-1 with the request,
// in order. Subtotal/TaxTotal/GrandTotal are sums across all lines.
// Breakdown groups tax by component (across the whole sale), suitable for
// rendering "CGST 9% ₹12.50 / SGST 9% ₹12.50" on a receipt.
type ComputeResponse struct {
	Lines      []LineTax
	Subtotal   payments.Money
	TaxTotal   payments.Money
	GrandTotal payments.Money
	Breakdown  []ComponentTotal
}

// LineTax is the per-line tax result.
type LineTax struct {
	SKU        string
	Net        payments.Money // tax-exclusive line amount
	Tax        payments.Money // total tax on the line
	Gross      payments.Money // Net + Tax
	Components []ComponentTax // per-component split; Σ Amount = Tax
}

// ComponentTax is a per-component tax on a single line.
type ComponentTax struct {
	ComponentID string
	Name        string
	RateBP      int32
	Amount      payments.Money
}

// ComponentTotal aggregates one component across the whole sale.
type ComponentTotal struct {
	ComponentID string
	Name        string
	RateBP      int32
	Amount      payments.Money
}
