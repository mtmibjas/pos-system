package expenses

import "errors"

// ErrInvalidExpense is returned when Create() rejects a malformed expense
// (empty tenant/store, missing date/category, or an amount with no
// currency). The api layer maps this to InvalidArgument.
var ErrInvalidExpense = errors.New("expenses: invalid expense")
