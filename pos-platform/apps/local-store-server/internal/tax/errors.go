package tax

import "errors"

// ErrCategoryNotFound is returned when a line references a tax_category_id
// that does not exist (or is archived) for the request's tenant.
var ErrCategoryNotFound = errors.New("tax: category not found")

// ErrEmptyTenant is returned when ComputeRequest.TenantID is unset.
var ErrEmptyTenant = errors.New("tax: TenantID is required")

// ErrCurrencyMix is returned when lines on the same compute request use
// different currencies.
var ErrCurrencyMix = errors.New("tax: mixed currencies are not allowed")

// ErrOverflow is returned when fixed-point math would exceed int64 range.
// In practice this requires a single line total above ~9 × 10^8 currency
// units, which exceeds any realistic POS transaction.
var ErrOverflow = errors.New("tax: arithmetic overflow")
