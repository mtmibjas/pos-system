/// FutureProvider that drives the today screen.
///
/// Single source of truth for the dashboard's AsyncValue. The screen
/// calls `ref.invalidate(todayControllerProvider)` on pull-to-refresh.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'today_models.dart';
import 'today_repository.dart';

final todayControllerProvider = FutureProvider<TodayDashboard>((ref) async {
  final repo = ref.watch(todayRepositoryProvider);
  return repo.fetchToday();
});
