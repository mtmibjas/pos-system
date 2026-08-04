// Package expenses is the store expense-ledger data-access layer.
//
// An Expense is operator-recorded outgoing spend: a date, category,
// description, payment mode, a gross amount and (optionally) the input
// VAT paid on it. The desktop Expenses screen lists them; a cloud-side
// GL projection may consume them later.
//
// Expenses are NOT sync events — they mutate the local store ledger
// directly, like items and tax_categories. ExpenseService.CreateExpense
// (and the cmd/seed-demo helper) are the only write paths.
package expenses

import (
	"time"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/payments"
)

// Expense is one row in the store expense ledger.
//
// Amount / VAT are decomposed via payments.Money — no floats in this
// struct. VAT may be a zero Money (currency kept) when no input VAT
// applies. Date is a display-friendly YYYY-MM-DD string; the ledger
// groups/reports on it but never does arithmetic.
type Expense struct {
	ID          string
	TenantID    string
	StoreID     string
	Date        string
	Category    string
	Description string
	PaymentMode string
	Amount      payments.Money
	VAT         payments.Money
	CreatedAt   time.Time
}
