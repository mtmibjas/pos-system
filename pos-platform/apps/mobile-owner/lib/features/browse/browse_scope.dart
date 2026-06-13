/// State for the browse screen's filter controls — period, anchor date,
/// optional store filter. Exposed as a StateNotifier so changes trigger
/// a re-fetch in browse_controller without rebuilding the whole tree.
///
/// Anchor stepping math lives here (not in the controller / screen) so
/// it's unit-testable in isolation and consistent across UI surfaces:
///
///   Day   ◀ anchor−1d   ▶ anchor+1d
///   Week  ◀ Monday−7d   ▶ Monday+7d   (anchor snaps to Monday on display)
///   Month ◀ prev 1st    ▶ next 1st
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

enum BrowsePeriod { day, week, month }

extension BrowsePeriodWire on BrowsePeriod {
  String get wire => switch (this) {
        BrowsePeriod.day => 'day',
        BrowsePeriod.week => 'week',
        BrowsePeriod.month => 'month',
      };

  String get label => switch (this) {
        BrowsePeriod.day => 'Day',
        BrowsePeriod.week => 'Week',
        BrowsePeriod.month => 'Month',
      };
}

class BrowseScope {
  final BrowsePeriod period;

  /// `anchor` is normalised to the START of the bucket containing the
  /// date the user selected:
  ///   day   → that day (midnight)
  ///   week  → Monday of that week
  ///   month → 1st of that month
  /// Always at 00:00:00 local time, no sub-day component.
  final DateTime anchor;

  /// Empty string = "all stores". Matches cloud-api's `store_id=` query
  /// param semantics so the repository can pass it through directly.
  final String storeId;

  const BrowseScope({
    required this.period,
    required this.anchor,
    required this.storeId,
  });

  BrowseScope copyWith({
    BrowsePeriod? period,
    DateTime? anchor,
    String? storeId,
  }) =>
      BrowseScope(
        period: period ?? this.period,
        anchor: anchor ?? this.anchor,
        storeId: storeId ?? this.storeId,
      );

  /// Half-open [from, to) covering the current anchor's bucket.
  ({DateTime from, DateTime to}) get window {
    switch (period) {
      case BrowsePeriod.day:
        return (from: anchor, to: anchor.add(const Duration(days: 1)));
      case BrowsePeriod.week:
        final monday = startOfWeek(anchor);
        return (from: monday, to: monday.add(const Duration(days: 7)));
      case BrowsePeriod.month:
        final first = DateTime(anchor.year, anchor.month, 1);
        final next = DateTime(anchor.year, anchor.month + 1, 1);
        return (from: first, to: next);
    }
  }
}

/// Returns the local-time midnight Monday on or before [d].
DateTime startOfWeek(DateTime d) {
  final justDate = DateTime(d.year, d.month, d.day);
  // DateTime.weekday is 1 (Mon) .. 7 (Sun).
  return justDate.subtract(Duration(days: justDate.weekday - 1));
}

DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

/// Snap any date to the start of its period bucket.
DateTime snapAnchor(BrowsePeriod period, DateTime d) {
  switch (period) {
    case BrowsePeriod.day:
      return startOfDay(d);
    case BrowsePeriod.week:
      return startOfWeek(d);
    case BrowsePeriod.month:
      return DateTime(d.year, d.month, 1);
  }
}

class BrowseScopeNotifier extends StateNotifier<BrowseScope> {
  BrowseScopeNotifier(DateTime Function() now)
      : _now = now,
        super(BrowseScope(
          period: BrowsePeriod.day,
          anchor: startOfDay(now()),
          storeId: '',
        ));

  final DateTime Function() _now;

  void setPeriod(BrowsePeriod p) {
    // Re-snap anchor under the new period — Day→Week of Wed snaps back
    // to Monday, Day→Month snaps to the 1st, etc.
    state = state.copyWith(period: p, anchor: snapAnchor(p, state.anchor));
  }

  void setStoreId(String id) => state = state.copyWith(storeId: id);

  /// Step anchor backward by one bucket (always allowed).
  void previous() {
    state = state.copyWith(anchor: _shift(state.period, state.anchor, -1));
  }

  /// Step anchor forward by one bucket. Capped so the anchor's bucket
  /// can never extend past today — owners shouldn't be able to ask for
  /// future periods that are guaranteed empty.
  void next() {
    final candidate = _shift(state.period, state.anchor, 1);
    final today = snapAnchor(state.period, _now());
    if (candidate.isAfter(today)) return;
    state = state.copyWith(anchor: candidate);
  }

  /// True if [next] would no-op — surfaces the "▶ disabled" state.
  bool get canStepForward {
    final candidate = _shift(state.period, state.anchor, 1);
    final today = snapAnchor(state.period, _now());
    return !candidate.isAfter(today);
  }

  static DateTime _shift(BrowsePeriod p, DateTime anchor, int delta) {
    switch (p) {
      case BrowsePeriod.day:
        return anchor.add(Duration(days: delta));
      case BrowsePeriod.week:
        return anchor.add(Duration(days: 7 * delta));
      case BrowsePeriod.month:
        return DateTime(anchor.year, anchor.month + delta, 1);
    }
  }
}

final browseScopeProvider =
    StateNotifierProvider<BrowseScopeNotifier, BrowseScope>(
  (ref) => BrowseScopeNotifier(DateTime.now),
);
