/// Shared exponential-backoff-with-jitter utility
/// (docs/desktop-connection-resilience.md §4.3).
///
/// Extracted from the inline math that lived in `realtime.dart`'s reconnect
/// loop so the realtime channel, the RPC retry policy, and the idle health
/// probe all use ONE tested implementation. Exponential growth (×2) capped
/// at [max], with additive random jitter to avoid a thundering herd when
/// many counters wake at once after a power blip.
library;

import 'dart:math';

class Backoff {
  Backoff({
    this.initial = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.factor = 2,
    this.maxJitter = const Duration(milliseconds: 250),
    Random? random,
  })  : _current = initial,
        _random = random ?? Random();

  final Duration initial;
  final Duration max;
  final int factor;
  final Duration maxJitter;
  final Random _random;

  Duration _current;

  /// The delay to wait before the next attempt, then advances the internal
  /// counter (exponential, capped). Jitter is added on top of the cap so
  /// even at steady-state the wakeups stay spread out.
  Duration next() {
    final base = _current > max ? max : _current;
    final jitterMs = _random.nextInt(maxJitter.inMilliseconds + 1);
    final delay = base + Duration(milliseconds: jitterMs);

    final grown = _current * factor;
    _current = grown > max ? max : grown;
    return delay;
  }

  /// Reset back to [initial] — call after a successful attempt.
  void reset() => _current = initial;
}
