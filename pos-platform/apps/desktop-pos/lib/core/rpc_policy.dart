/// RPC resilience policy — a Connect interceptor
/// (docs/desktop-connection-resilience.md §4).
///
/// Wraps every UNARY call with three universally-safe behaviors:
///   1. a typed timeout so a dead/slow store server never hangs the till;
///   2. error classification → a health signal (transport failure vs. a
///      server answer — even a business error proves reachability);
///   3. bounded retry with backoff — **opt-in per call**, for idempotent
///      reads only. Writes are never auto-retried here; their ambiguous-
///      response replay is deliberately step 6's job (§4.2 boundary).
///
/// Per-call policy is carried in request headers (repositories set them via
/// [readCallHeaders]/[writeCallHeaders]); the interceptor consumes and strips
/// them so they never go over the wire.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;

import '../domain/connection_health.dart';
import 'backoff.dart';

/// Internal per-call headers. Lowercase (Connect normalizes anyway).
const _kRetryHeader = 'x-pos-retry';
const _kDeadlineHeader = 'x-pos-deadline-ms';

const _defaultReadDeadline = Duration(seconds: 5); // §6 Q6.2
const _defaultWriteDeadline = Duration(seconds: 10);
const _maxRetryAttempts = 3; // reads only

/// Headers for an idempotent READ: enables retry + the 5 s read deadline.
connect.Headers readCallHeaders({Duration? deadline}) {
  return connect.Headers()
    ..[_kRetryHeader] = 'idempotent'
    ..[_kDeadlineHeader] = (deadline ?? _defaultReadDeadline).inMilliseconds.toString();
}

/// Headers for a WRITE: no retry, 10 s deadline. A failed write surfaces a
/// clean error for the caller to handle (step 6 owns the replay decision).
connect.Headers writeCallHeaders({Duration? deadline}) {
  return connect.Headers()
    ..[_kDeadlineHeader] = (deadline ?? _defaultWriteDeadline).inMilliseconds.toString();
}

/// The two callbacks the interceptor uses to feed the health aggregator.
/// Kept as a tiny value so the interceptor has no Riverpod dependency and is
/// unit-testable with a stub reporter.
class ConnectionReporter {
  const ConnectionReporter({required this.onSuccess, required this.onFailure});
  final void Function() onSuccess;
  final void Function(FailureKind kind, String summary) onFailure;

  /// A no-op reporter for tests that don't assert on health.
  static const ConnectionReporter noop = ConnectionReporter(
    onSuccess: _noopSuccess,
    onFailure: _noopFailure,
  );
  static void _noopSuccess() {}
  static void _noopFailure(FailureKind _, String __) {}
}

class _CallPolicy {
  const _CallPolicy({required this.deadline, required this.retry});
  final Duration deadline;
  final bool retry;
}

_CallPolicy _policyFor(connect.Headers headers) {
  final retry = headers[_kRetryHeader] == 'idempotent';
  final deadlineMs = int.tryParse(headers[_kDeadlineHeader] ?? '');
  final deadline = deadlineMs != null
      ? Duration(milliseconds: deadlineMs)
      : (retry ? _defaultReadDeadline : _defaultWriteDeadline);
  return _CallPolicy(deadline: deadline, retry: retry);
}

/// Classify a Connect error. Returns the [FailureKind] for a *transport*
/// failure (server didn't answer), or `null` when the server DID answer —
/// a business/auth error still proves reachability.
FailureKind? classifyTransportFailure(connect.ConnectException e) {
  if (e.cause is SocketException) return FailureKind.refused;
  switch (e.code) {
    case connect.Code.unavailable:
    case connect.Code.deadlineExceeded:
      return FailureKind.transient;
    default:
      return null; // invalidArgument / failedPrecondition / unauthenticated / …
  }
}

/// Build the resilience interceptor bound to [reporter].
connect.Interceptor resilienceInterceptor(ConnectionReporter reporter) {
  return <I extends Object, O extends Object>(connect.AnyFn<I, O> next) {
    return (connect.Request<I, O> req) async {
      // Only unary calls are wrapped; streaming passes straight through
      // (realtime uses a raw WebSocket, not a Connect stream).
      if (req.spec.streamType != connect.StreamType.unary) {
        return next(req);
      }

      final policy = _policyFor(req.headers);
      // Consume the internal headers so they never hit the wire.
      req.headers.remove(_kRetryHeader);
      req.headers.remove(_kDeadlineHeader);

      final backoff = Backoff(
        initial: const Duration(milliseconds: 200),
        max: const Duration(seconds: 2),
      );
      var attempt = 0;

      while (true) {
        attempt++;
        try {
          // NOTE: .timeout throws but does not cancel the in-flight socket;
          // acceptable at POS RPC volume. A future refinement can compose a
          // DeadlineSignal so the transport aborts eagerly.
          final res = await next(req).timeout(policy.deadline);
          reporter.onSuccess();
          return res;
        } on TimeoutException {
          reporter.onFailure(FailureKind.transient, 'request timed out');
          if (policy.retry && attempt < _maxRetryAttempts) {
            await Future<void>.delayed(backoff.next());
            continue;
          }
          throw connect.ConnectException(
            connect.Code.deadlineExceeded,
            'store server did not respond in time',
          );
        } on connect.ConnectException catch (e) {
          final kind = classifyTransportFailure(e);
          if (kind == null) {
            // The server answered (business/auth error) → reachable.
            reporter.onSuccess();
            rethrow;
          }
          reporter.onFailure(kind, e.message);
          if (policy.retry &&
              kind == FailureKind.transient &&
              attempt < _maxRetryAttempts) {
            await Future<void>.delayed(backoff.next());
            continue;
          }
          rethrow;
        }
      }
    };
  };
}
