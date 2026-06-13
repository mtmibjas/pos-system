package tax

import (
	"context"
	"fmt"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// nanosPerUnit mirrors payments.Money's scale (1 currency unit = 10^9 nanos).
const nanosPerUnit int64 = 1_000_000_000

// basisPointsDenominator: 10000 basis points = 100%.
const bpDenominator int64 = 10_000

// Engine computes tax on a cart, server-authoritative.
type Engine struct {
	store *Store
}

func NewEngine(store *Store) *Engine {
	return &Engine{store: store}
}

// Compute resolves each line against its tax category and returns the
// per-line tax breakdown plus the aggregate Subtotal / TaxTotal /
// GrandTotal. The per-component split is rounded so that the breakdown
// sum exactly equals the line tax — no penny-drift on the receipt.
//
// Empty TaxCategoryID is treated as EXEMPT: tax = 0, net = gross = line total.
// Any non-empty id that does not resolve to a live category returns
// ErrCategoryNotFound.
func (e *Engine) Compute(ctx context.Context, req ComputeRequest) (ComputeResponse, error) {
	if req.TenantID == "" {
		return ComputeResponse{}, ErrEmptyTenant
	}
	if len(req.Lines) == 0 {
		return ComputeResponse{Lines: []LineTax{}}, nil
	}

	// Resolve currency up front; mixing is not supported.
	currency := req.Lines[0].LineTotal.CurrencyCode
	if currency == "" {
		return ComputeResponse{}, fmt.Errorf("tax: missing currency on first line (sku=%s)", req.Lines[0].SKU)
	}
	for _, ln := range req.Lines[1:] {
		if ln.LineTotal.CurrencyCode != currency {
			return ComputeResponse{}, ErrCurrencyMix
		}
	}

	// Batch-load categories referenced by lines.
	ids := make([]string, 0, len(req.Lines))
	for _, ln := range req.Lines {
		if ln.TaxCategoryID != "" {
			ids = append(ids, ln.TaxCategoryID)
		}
	}
	cats, err := e.store.loadCategoriesBatch(ctx, req.TenantID, ids)
	if err != nil {
		return ComputeResponse{}, err
	}

	resp := ComputeResponse{
		Lines:      make([]LineTax, 0, len(req.Lines)),
		Subtotal:   payments.Money{CurrencyCode: currency},
		TaxTotal:   payments.Money{CurrencyCode: currency},
		GrandTotal: payments.Money{CurrencyCode: currency},
	}
	// Component totals, keyed by component_id, accumulated as nanos.
	type compAcc struct {
		comp   Component
		nanos  int64
	}
	compTotals := map[string]*compAcc{}
	compOrder := []string{} // first-seen order for stable Breakdown output

	for _, ln := range req.Lines {
		lineNanos, ok := moneyToNanos(ln.LineTotal)
		if !ok {
			return ComputeResponse{}, fmt.Errorf("%w: line %s", ErrOverflow, ln.SKU)
		}

		var (
			netNanos   int64
			taxNanos   int64
			compParts  []ComponentTax
			components []Component
			cat        Category
			catFound   bool
		)

		if ln.TaxCategoryID == "" {
			// Exempt: no category lookup, no tax.
			netNanos = lineNanos
		} else {
			cat, catFound = cats[ln.TaxCategoryID]
			if !catFound {
				return ComputeResponse{}, fmt.Errorf("%w: sku=%s id=%s",
					ErrCategoryNotFound, ln.SKU, ln.TaxCategoryID)
			}
			components = cat.Components
			totalRate := cat.TotalRateBP()
			if totalRate == 0 || len(components) == 0 {
				// Category defined but has no rate (treated as exempt).
				netNanos = lineNanos
			} else if cat.PriceIncludesTax {
				netNanos, taxNanos, compParts, err = splitInclusive(currency, lineNanos, components, totalRate)
				if err != nil {
					return ComputeResponse{}, err
				}
			} else {
				netNanos, taxNanos, compParts, err = splitExclusive(currency, lineNanos, components, totalRate)
				if err != nil {
					return ComputeResponse{}, err
				}
			}
		}

		grossNanos := netNanos + taxNanos
		lt := LineTax{
			SKU:        ln.SKU,
			Net:        nanosToMoney(currency, netNanos),
			Tax:        nanosToMoney(currency, taxNanos),
			Gross:      nanosToMoney(currency, grossNanos),
			Components: compParts,
		}
		resp.Lines = append(resp.Lines, lt)

		// Accumulate aggregates.
		if err := addNanosInto(&resp.Subtotal, currency, netNanos); err != nil {
			return ComputeResponse{}, err
		}
		if err := addNanosInto(&resp.TaxTotal, currency, taxNanos); err != nil {
			return ComputeResponse{}, err
		}
		if err := addNanosInto(&resp.GrandTotal, currency, grossNanos); err != nil {
			return ComputeResponse{}, err
		}
		for _, p := range compParts {
			pn, ok := moneyToNanos(p.Amount)
			if !ok {
				return ComputeResponse{}, ErrOverflow
			}
			acc, ok := compTotals[p.ComponentID]
			if !ok {
				// Find the Component definition for this part.
				var compDef Component
				for _, c := range components {
					if c.ID == p.ComponentID {
						compDef = c
						break
					}
				}
				acc = &compAcc{comp: compDef}
				compTotals[p.ComponentID] = acc
				compOrder = append(compOrder, p.ComponentID)
			}
			acc.nanos += pn
		}
	}

	for _, id := range compOrder {
		acc := compTotals[id]
		resp.Breakdown = append(resp.Breakdown, ComponentTotal{
			ComponentID: acc.comp.ID,
			Name:        acc.comp.Name,
			RateBP:      acc.comp.RateBP,
			Amount:      nanosToMoney(currency, acc.nanos),
		})
	}
	return resp, nil
}

// --- math helpers ---

// splitExclusive applies tax on top of a net line amount.
//   net   = lineNanos
//   tax   = round(lineNanos * totalRate / 10000)
//   per-component = round(lineNanos * r_i / 10000); largest absorbs residue.
func splitExclusive(currency string, lineNanos int64, components []Component, totalRate int64) (int64, int64, []ComponentTax, error) {
	netNanos := lineNanos
	totalTax, ok := mulDivRound(lineNanos, totalRate, bpDenominator)
	if !ok {
		return 0, 0, nil, ErrOverflow
	}
	parts, err := splitComponents(currency, lineNanos, components, bpDenominator, totalTax)
	if err != nil {
		return 0, 0, nil, err
	}
	return netNanos, totalTax, parts, nil
}

// splitInclusive extracts tax from a gross line amount.
//   net  = lineNanos * 10000 / (10000 + totalRate)
//   tax  = lineNanos - net
//   per-component = round(tax * r_i / totalRate); largest absorbs residue.
func splitInclusive(currency string, lineNanos int64, components []Component, totalRate int64) (int64, int64, []ComponentTax, error) {
	netNanos, ok := mulDivRound(lineNanos, bpDenominator, bpDenominator+totalRate)
	if !ok {
		return 0, 0, nil, ErrOverflow
	}
	taxNanos := lineNanos - netNanos
	// For inclusive, the per-component split denominator is totalRate
	// (we're dividing the extracted tax in proportion to component rates).
	parts, err := splitComponents(currency, taxNanos, components, totalRate, taxNanos)
	if err != nil {
		return 0, 0, nil, err
	}
	return netNanos, taxNanos, parts, nil
}

// splitComponents distributes targetSum across the components, weighting
// by their rate. The basis used to compute each share is:
//   share_i = round(basisAmount * r_i / denominator)
// After computing all shares, the residue (targetSum - Σ shares) is
// absorbed by the component with the largest rate so that Σ = targetSum
// exactly. This is the rule that prevents receipts showing
// "CGST 9.00 + SGST 9.01 = 18.00" rounding artifacts.
//
// basisAmount is the amount being split (gross net for exclusive,
// extracted tax for inclusive); denominator is whichever proportion is
// being applied (bpDenominator for exclusive, totalRate for inclusive).
func splitComponents(currency string, basisAmount int64, components []Component, denominator, targetSum int64) ([]ComponentTax, error) {
	parts := make([]ComponentTax, len(components))
	var assigned int64
	largestIdx := 0
	for i, c := range components {
		share, ok := mulDivRound(basisAmount, int64(c.RateBP), denominator)
		if !ok {
			return nil, ErrOverflow
		}
		parts[i] = ComponentTax{
			ComponentID: c.ID,
			Name:        c.Name,
			RateBP:      c.RateBP,
			Amount:      nanosToMoney(currency, share),
		}
		assigned += share
		if c.RateBP > components[largestIdx].RateBP {
			largestIdx = i
		}
	}
	// Absorb residue into the largest-rate component.
	residue := targetSum - assigned
	if residue != 0 {
		curNanos, _ := moneyToNanos(parts[largestIdx].Amount)
		parts[largestIdx].Amount = nanosToMoney(currency, curNanos+residue)
	}
	return parts, nil
}

// mulDivRound computes round(a * b / d) with half-away-from-zero rounding.
// Returns (result, ok). ok=false on int64 overflow during multiplication.
func mulDivRound(a, b, d int64) (int64, bool) {
	if d == 0 {
		return 0, false
	}
	// Overflow check: if a != 0 and (a*b)/a != b, we wrapped.
	prod := a * b
	if a != 0 && prod/a != b {
		return 0, false
	}
	// Half-away-from-zero.
	if (prod < 0) != (d < 0) {
		// Negative result.
		return (prod - d/2) / d, true
	}
	return (prod + d/2) / d, true
}

// moneyToNanos returns (total_nanos, ok). ok=false on int64 overflow.
func moneyToNanos(m payments.Money) (int64, bool) {
	prod := m.Units * nanosPerUnit
	if m.Units != 0 && prod/nanosPerUnit != m.Units {
		return 0, false
	}
	return prod + int64(m.Nanos), true
}

// nanosToMoney reconstructs a Money. For positive n, units and nanos are
// both non-negative. For negative n, both are non-positive (matching the
// payments.Money sign rule).
func nanosToMoney(currency string, n int64) payments.Money {
	units := n / nanosPerUnit
	nanos := n - units*nanosPerUnit
	return payments.Money{CurrencyCode: currency, Units: units, Nanos: int32(nanos)}
}

// addNanosInto accumulates n into the existing Money in-place.
func addNanosInto(dst *payments.Money, currency string, n int64) error {
	cur, ok := moneyToNanos(*dst)
	if !ok {
		return ErrOverflow
	}
	*dst = nanosToMoney(currency, cur+n)
	return nil
}
