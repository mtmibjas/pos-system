import 'package:flutter_test/flutter_test.dart';

import 'package:mobile_owner/features/browse/browse_scope.dart';

DateTime _fixedNow() => DateTime(2026, 5, 31, 14, 30); // a Sunday

void main() {
  group('snapAnchor', () {
    test('Day snaps to midnight', () {
      final d = DateTime(2026, 5, 31, 14, 30);
      final s = snapAnchor(BrowsePeriod.day, d);
      expect(s, DateTime(2026, 5, 31));
    });

    test('Week snaps to Monday', () {
      // 2026-05-31 is a Sunday → Monday is May 25.
      final s = snapAnchor(BrowsePeriod.week, DateTime(2026, 5, 31));
      expect(s, DateTime(2026, 5, 25));
      expect(s.weekday, DateTime.monday);
    });

    test('Month snaps to first', () {
      final s = snapAnchor(BrowsePeriod.month, DateTime(2026, 5, 31));
      expect(s, DateTime(2026, 5, 1));
    });
  });

  group('BrowseScope.window', () {
    test('Day → [anchor, anchor+1d)', () {
      final scope = BrowseScope(
        period: BrowsePeriod.day,
        anchor: DateTime(2026, 5, 31),
        storeId: '',
      );
      final w = scope.window;
      expect(w.from, DateTime(2026, 5, 31));
      expect(w.to, DateTime(2026, 6, 1));
    });

    test('Week → [Monday, Monday+7d)', () {
      final scope = BrowseScope(
        period: BrowsePeriod.week,
        anchor: DateTime(2026, 5, 25), // Monday
        storeId: '',
      );
      final w = scope.window;
      expect(w.from, DateTime(2026, 5, 25));
      expect(w.to, DateTime(2026, 6, 1));
    });

    test('Month → [1st, next 1st)', () {
      final scope = BrowseScope(
        period: BrowsePeriod.month,
        anchor: DateTime(2026, 5, 1),
        storeId: '',
      );
      final w = scope.window;
      expect(w.from, DateTime(2026, 5, 1));
      expect(w.to, DateTime(2026, 6, 1));
    });
  });

  group('BrowseScopeNotifier stepping', () {
    test('Day previous/next move by 1 day', () {
      final n = BrowseScopeNotifier(_fixedNow);
      expect(n.state.anchor, DateTime(2026, 5, 31));
      n.previous();
      expect(n.state.anchor, DateTime(2026, 5, 30));
      n.next();
      expect(n.state.anchor, DateTime(2026, 5, 31));
    });

    test('cannot step past today', () {
      final n = BrowseScopeNotifier(_fixedNow);
      expect(n.canStepForward, isFalse);
      n.next(); // no-op
      expect(n.state.anchor, DateTime(2026, 5, 31));
    });

    test('previous always works', () {
      final n = BrowseScopeNotifier(_fixedNow);
      for (var i = 0; i < 10; i++) {
        n.previous();
      }
      expect(n.state.anchor, DateTime(2026, 5, 21));
    });

    test('Month previous goes to prev calendar month', () {
      final n = BrowseScopeNotifier(_fixedNow);
      n.setPeriod(BrowsePeriod.month);
      expect(n.state.anchor, DateTime(2026, 5, 1));
      n.previous();
      expect(n.state.anchor, DateTime(2026, 4, 1));
    });

    test('setPeriod re-snaps anchor', () {
      // Start with Day anchored on May 31 (a Sunday).
      final n = BrowseScopeNotifier(_fixedNow);
      n.setPeriod(BrowsePeriod.week);
      // Sunday → previous Monday (May 25).
      expect(n.state.anchor, DateTime(2026, 5, 25));
      n.setPeriod(BrowsePeriod.month);
      expect(n.state.anchor, DateTime(2026, 5, 1));
    });

    test('setStoreId is independent of date', () {
      final n = BrowseScopeNotifier(_fixedNow);
      n.setStoreId('store-A');
      expect(n.state.storeId, 'store-A');
      expect(n.state.anchor, DateTime(2026, 5, 31));
      n.setStoreId('');
      expect(n.state.storeId, '');
    });
  });
}
