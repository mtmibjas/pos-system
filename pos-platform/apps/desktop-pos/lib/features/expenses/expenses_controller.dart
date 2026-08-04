/// Controller for the Expenses screen.
///
/// Wraps ExpenseService.ListExpenses in a Riverpod AsyncNotifier —
/// mirrors ItemsController. `build()` kicks off the initial fetch so the
/// UI shows a loading spinner on mount; `refresh()` re-runs the call for
/// the manual reload button.
library;

import 'package:pos_sdk/gen/pos/v1/expense_service.connect.client.dart';
import 'package:pos_sdk/gen/pos/v1/expense_service.pb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/transport.dart';

part 'expenses_controller.g.dart';

@riverpod
class ExpensesController extends _$ExpensesController {
  @override
  Future<List<Expense>> build() async {
    return _fetch();
  }

  /// Re-fetch the expense ledger. UI transitions to loading then either
  /// data or error — same shape as `build()`.
  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_fetch);
  }

  Future<List<Expense>> _fetch() async {
    final client = ExpenseServiceClient(ref.read(transportProvider));
    final resp = await client.listExpenses(ListExpensesRequest());
    return resp.expenses;
  }
}
