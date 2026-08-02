/// Unit tests for the shared exponential-backoff utility (backoff.dart).
library;

import 'dart:math';

import 'package:desktop_pos/core/backoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Backoff', () {
    test('grows exponentially and caps at max (jitter=0)', () {
      final b = Backoff(
        initial: const Duration(seconds: 1),
        max: const Duration(seconds: 8),
        maxJitter: Duration.zero,
      );
      // base grows 1,2,4,8,8,8 — capped.
      expect(b.next(), const Duration(seconds: 1));
      expect(b.next(), const Duration(seconds: 2));
      expect(b.next(), const Duration(seconds: 4));
      expect(b.next(), const Duration(seconds: 8));
      expect(b.next(), const Duration(seconds: 8));
    });

    test('reset returns to initial', () {
      final b = Backoff(
        initial: const Duration(seconds: 1),
        max: const Duration(seconds: 8),
        maxJitter: Duration.zero,
      );
      b.next();
      b.next();
      b.reset();
      expect(b.next(), const Duration(seconds: 1));
    });

    test('jitter stays within [0, maxJitter] of the base', () {
      final b = Backoff(
        initial: const Duration(seconds: 1),
        max: const Duration(seconds: 30),
        maxJitter: const Duration(milliseconds: 250),
        random: Random(42),
      );
      final d = b.next();
      expect(d.inMilliseconds, greaterThanOrEqualTo(1000));
      expect(d.inMilliseconds, lessThanOrEqualTo(1250));
    });
  });
}
