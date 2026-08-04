package api

import (
	"context"
	"errors"

	"connectrpc.com/connect"

	"github.com/mibjas/pos-platform/apps/local-store-server/internal/expenses"
	posv1 "github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1"
	"github.com/mibjas/pos-platform/packages/sdk-go/gen/pos/v1/posv1connect"
)

// api-layer sentinel for ExpenseService input validation.
var errMissingExpense = errors.New("api: CreateExpenseRequest.expense is required")

// ExpenseHandler adapts expenses.Store to
// posv1connect.ExpenseServiceHandler.
//
// tenantID / storeID are pinned from server config — the wire tenant_id /
// store_id on the Expense message are ignored (single tenant+store per
// server instance, mirroring ItemHandler).
type ExpenseHandler struct {
	posv1connect.UnimplementedExpenseServiceHandler
	store    *expenses.Store
	tenantID string
	storeID  string
}

// NewExpenseHandler wraps a non-nil expenses.Store.
func NewExpenseHandler(store *expenses.Store, tenantID, storeID string) *ExpenseHandler {
	if store == nil {
		panic("api: NewExpenseHandler requires a non-nil *expenses.Store")
	}
	if tenantID == "" {
		panic("api: NewExpenseHandler requires tenantID")
	}
	if storeID == "" {
		panic("api: NewExpenseHandler requires storeID")
	}
	return &ExpenseHandler{store: store, tenantID: tenantID, storeID: storeID}
}

func (h *ExpenseHandler) ListExpenses(
	ctx context.Context,
	_ *connect.Request[posv1.ListExpensesRequest],
) (*connect.Response[posv1.ListExpensesResponse], error) {
	rows, err := h.store.List(ctx, h.tenantID, h.storeID)
	if err != nil {
		return nil, toConnectErr(err)
	}
	out := make([]*posv1.Expense, 0, len(rows))
	for _, e := range rows {
		out = append(out, expenseToProto(e))
	}
	return connect.NewResponse(&posv1.ListExpensesResponse{
		Expenses: out,
	}), nil
}

func (h *ExpenseHandler) CreateExpense(
	ctx context.Context,
	req *connect.Request[posv1.CreateExpenseRequest],
) (*connect.Response[posv1.CreateExpenseResponse], error) {
	in := req.Msg.GetExpense()
	if in == nil {
		return nil, connect.NewError(connect.CodeInvalidArgument, errMissingExpense)
	}
	domain := expenses.Expense{
		ID:          in.GetId(),
		TenantID:    h.tenantID, // server-pinned
		StoreID:     h.storeID,  // server-pinned
		Date:        in.GetDate(),
		Category:    in.GetCategory(),
		Description: in.GetDescription(),
		PaymentMode: in.GetPaymentMode(),
		Amount:      moneyFromProto(in.GetAmount()),
		VAT:         moneyFromProto(in.GetVat()),
	}
	stored, err := h.store.Create(ctx, domain)
	if err != nil {
		return nil, toConnectErr(err)
	}
	return connect.NewResponse(&posv1.CreateExpenseResponse{
		Expense: expenseToProto(stored),
	}), nil
}

// --- helpers ---

func expenseToProto(e expenses.Expense) *posv1.Expense {
	return &posv1.Expense{
		Id:          e.ID,
		TenantId:    e.TenantID,
		StoreId:     e.StoreID,
		Date:        e.Date,
		Category:    e.Category,
		Description: e.Description,
		PaymentMode: e.PaymentMode,
		Amount:      moneyToProto(e.Amount),
		Vat:         moneyToProto(e.VAT),
		CreatedAt:   e.CreatedAt.UnixNano(),
	}
}
