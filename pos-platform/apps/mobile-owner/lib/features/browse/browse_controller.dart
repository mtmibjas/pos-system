/// FutureProvider that combines the current browse scope with the
/// repository call. Re-fetches automatically whenever the scope changes
/// (Riverpod's reactive `watch` does this for us).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../today/today_models.dart';
import 'browse_repository.dart';
import 'browse_scope.dart';

final browseControllerProvider =
    FutureProvider<List<SalesSummaryBucket>>((ref) async {
  final scope = ref.watch(browseScopeProvider);
  return ref.watch(browseRepositoryProvider).fetchSummary(scope);
});
