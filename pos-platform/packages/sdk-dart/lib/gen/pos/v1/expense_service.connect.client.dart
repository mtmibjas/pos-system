//
//  Generated code. Do not modify.
//  source: pos/v1/expense_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "expense_service.pb.dart" as posv1expense_service;
import "expense_service.connect.spec.dart" as specs;

/// ExpenseService is the operator-facing expense ledger surface. The
/// desktop client lists store expenses (rent, utilities, salaries, …) to
/// render the Expenses screen, and can record a new expense.
/// Like ItemService and TaxAdminService, expense writes are NOT sync
/// events — they mutate the local store ledger directly. A cloud-side GL
/// projection may consume them later; until then, CreateExpense (and
/// cmd/seed-demo) are the only seed paths.
extension type ExpenseServiceClient (connect.Transport _transport) {
  Future<posv1expense_service.ListExpensesResponse> listExpenses(
    posv1expense_service.ListExpensesRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ExpenseService.listExpenses,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }

  Future<posv1expense_service.CreateExpenseResponse> createExpense(
    posv1expense_service.CreateExpenseRequest input, {
    connect.Headers? headers,
    connect.AbortSignal? signal,
    Function(connect.Headers)? onHeader,
    Function(connect.Headers)? onTrailer,
  }) {
    return connect.Client(_transport).unary(
      specs.ExpenseService.createExpense,
      input,
      signal: signal,
      headers: headers,
      onHeader: onHeader,
      onTrailer: onTrailer,
    );
  }
}
