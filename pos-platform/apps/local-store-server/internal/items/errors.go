package items

import "errors"

// ErrItemNotFound is returned when Get() / archived-aware lookups don't
// find a row for the requested (tenant, sku) pair.
var ErrItemNotFound = errors.New("items: not found")

// ErrInvalidItem is returned when Upsert() rejects a malformed item
// (empty SKU, name, currency, or a tax_category_id that doesn't exist
// for the tenant). The api layer maps this to InvalidArgument.
var ErrInvalidItem = errors.New("items: invalid item")
