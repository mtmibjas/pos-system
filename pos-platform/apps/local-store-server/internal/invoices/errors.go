package invoices

import "errors"

// ErrNotFound is returned by Get/GetBySale when the invoice does not exist.
var ErrNotFound = errors.New("invoices: not found")

// ErrAlreadyIssued is returned by IssueTx if an invoice already exists for
// the given sale_id. In normal flow this is unreachable — SaleService.Finalize
// short-circuits on prior SaleCreated before reaching IssueTx — but we
// surface it as a typed error rather than letting the bare UNIQUE
// constraint violation leak.
var ErrAlreadyIssued = errors.New("invoices: already issued for sale")
