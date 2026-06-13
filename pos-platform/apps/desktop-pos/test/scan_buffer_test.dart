/// ScanBuffer state-machine tests — covers happy path (chars + Enter),
/// inter-char timeout, max-length guard, and reset.
library;

import 'package:desktop_pos/features/items/scan_buffer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('accumulates chars and commits the payload', () {
    final b = ScanBuffer(clock: _frozenClock());
    'SKU-A'.split('').forEach(b.add);
    expect(b.commit(), 'SKU-A');
    expect(b.length, 0);
  });

  test('commit on empty buffer returns empty string', () {
    final b = ScanBuffer();
    expect(b.commit(), '');
  });

  test('inter-char timeout resets the buffer', () {
    var t = DateTime(2026, 1, 1);
    final b = ScanBuffer(
      interCharTimeout: const Duration(milliseconds: 50),
      clock: () => t,
    );
    b.add('X');
    b.add('Y');
    // Jump past the timeout — the next add should start fresh.
    t = t.add(const Duration(milliseconds: 200));
    b.add('A');
    b.add('B');
    expect(b.commit(), 'AB');
  });

  test('max length guard drops the runaway buffer', () {
    final b = ScanBuffer(maxLength: 4, clock: _frozenClock());
    for (final ch in 'ABCDE'.split('')) {
      b.add(ch);
    }
    // After 'ABCD' the next add resets, so the buffer is 'E'.
    expect(b.commit(), 'E');
  });

  test('reset() clears mid-scan state', () {
    final b = ScanBuffer(clock: _frozenClock());
    b.add('A');
    b.add('B');
    b.reset();
    expect(b.length, 0);
    expect(b.commit(), '');
  });

  test('rejects non-single-char input', () {
    final b = ScanBuffer();
    expect(() => b.add(''), throwsArgumentError);
    expect(() => b.add('AB'), throwsArgumentError);
  });
}

DateTime Function() _frozenClock() {
  final t = DateTime(2026, 1, 1);
  return () => t;
}
