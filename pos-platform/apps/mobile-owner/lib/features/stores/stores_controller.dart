import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'stores_models.dart';
import 'stores_repository.dart';

final storesControllerProvider =
    FutureProvider<List<StoreSummary>>((ref) async {
  return ref.watch(storesRepositoryProvider).fetchStores();
});
