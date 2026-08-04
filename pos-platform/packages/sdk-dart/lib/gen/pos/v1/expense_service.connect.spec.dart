//
//  Generated code. Do not modify.
//  source: pos/v1/expense_service.proto
//

import "package:connectrpc/connect.dart" as connect;
import "expense_service.pb.dart" as posv1expense_service;

/// ExpenseService is the operator-facing expense ledger surface. The
/// desktop client lists store expenses (rent, utilities, salaries, …) to
/// render the Expenses screen, and can record a new expense.
/// Like ItemService and TaxAdminService, expense writes are NOT sync
/// events — they mutate the local store ledger directly. A cloud-side GL
/// projection may consume them later; until then, CreateExpense (and
/// cmd/seed-demo) are the only seed paths.
abstract final class ExpenseService {
  /// Fully-qualified name of the ExpenseService service.
  static const name = 'pos.v1.ExpenseService';

  static const listExpenses = connect.Spec(
    '/$name/ListExpenses',
    connect.StreamType.unary,
    posv1expense_service.ListExpensesRequest.new,
    posv1expense_service.ListExpensesResponse.new,
  );

  static const createExpense = connect.Spec(
    '/$name/CreateExpense',
    connect.StreamType.unary,
    posv1expense_service.CreateExpenseRequest.new,
    posv1expense_service.CreateExpenseResponse.new,
  );
}
