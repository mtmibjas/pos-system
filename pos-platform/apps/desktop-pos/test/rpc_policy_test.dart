/// Unit tests for the RPC resilience interceptor (rpc_policy.dart).
///
/// Drives the interceptor directly with a stub `next` so we assert timeout,
/// error classification, health reporting, and read-only retry without a
/// transport or server.
library;

import 'dart:async';
import 'dart:io';

import 'package:connectrpc/connect.dart' as connect;
import 'package:desktop_pos/core/rpc_policy.dart';
import 'package:desktop_pos/domain/connection_health.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records what the interceptor reported so tests can assert on it.
class _RecordingReporter {
  int successes = 0;
  final List<FailureKind> failures = [];

  ConnectionReporter get reporter => ConnectionReporter(
        onSuccess: () => successes++,
        onFailure: (kind, _) => failures.add(kind),
      );
}

/// Build a unary request carrying [headers].
connect.UnaryRequest<Object, Object> _req(connect.Headers headers) {
  const spec = connect.Spec<Object, Object>(
    '/test.v1.Svc/Method',
    connect.StreamType.unary,
    Object.new,
    Object.new,
  );
  return connect.UnaryRequest<Object, Object>(
    spec,
    'http://127.0.0.1/test',
    headers,
    Object(),
    connect.CancelableSignal(),
  );
}

connect.UnaryResponse<Object, Object> _resp(
    connect.Spec<Object, Object> spec) {
  return connect.UnaryResponse<Object, Object>(
    spec,
    connect.Headers(),
    Object(),
    connect.Headers(),
  );
}

/// Run the interceptor around [next], returning the terminal result/throw.
Future<connect.Response<Object, Object>> _run(
  ConnectionReporter reporter,
  connect.Headers headers,
  connect.AnyFn<Object, Object> next,
) {
  final wrapped = resilienceInterceptor(reporter)(next);
  return wrapped(_req(headers));
}

void main() {
  group('classifyTransportFailure', () {
    test('SocketException cause → refused', () {
      final e = connect.ConnectException(
        connect.Code.unavailable,
        'boom',
        cause: const SocketException('Connection refused'),
      );
      expect(classifyTransportFailure(e), FailureKind.refused);
    });

    test('unavailable / deadlineExceeded → transient', () {
      expect(
        classifyTransportFailure(
            connect.ConnectException(connect.Code.unavailable, 'x')),
        FailureKind.transient,
      );
      expect(
        classifyTransportFailure(
            connect.ConnectException(connect.Code.deadlineExceeded, 'x')),
        FailureKind.transient,
      );
    });

    test('server-answered codes → null (reachable)', () {
      for (final c in [
        connect.Code.invalidArgument,
        connect.Code.failedPrecondition,
        connect.Code.unauthenticated,
        connect.Code.alreadyExists,
        connect.Code.notFound,
      ]) {
        expect(classifyTransportFailure(connect.ConnectException(c, 'x')), isNull,
            reason: '$c should count as a server answer');
      }
    });
  });

  group('interceptor', () {
    test('success reports reachable and returns the response', () async {
      final rec = _RecordingReporter();
      var calls = 0;
      final res = await _run(rec.reporter, writeCallHeaders(), (req) async {
        calls++;
        return _resp(req.spec);
      });
      expect(res, isA<connect.UnaryResponse<Object, Object>>());
      expect(calls, 1);
      expect(rec.successes, 1);
      expect(rec.failures, isEmpty);
    });

    test('business error → reachable, surfaced, NOT retried', () async {
      final rec = _RecordingReporter();
      var calls = 0;
      await expectLater(
        _run(rec.reporter, readCallHeaders(), (req) async {
          calls++;
          throw connect.ConnectException(
              connect.Code.failedPrecondition, 'oversell');
        }),
        throwsA(isA<connect.ConnectException>()),
      );
      expect(calls, 1, reason: 'server answered → no retry even for a read');
      expect(rec.successes, 1);
      expect(rec.failures, isEmpty);
    });

    test('idempotent read retries transient failures then succeeds', () async {
      final rec = _RecordingReporter();
      var calls = 0;
      final res = await _run(rec.reporter, readCallHeaders(), (req) async {
        calls++;
        if (calls < 3) {
          throw connect.ConnectException(connect.Code.unavailable, 'blip');
        }
        return _resp(req.spec);
      });
      expect(res, isA<connect.UnaryResponse<Object, Object>>());
      expect(calls, 3);
      expect(rec.failures, [FailureKind.transient, FailureKind.transient]);
      expect(rec.successes, 1);
    });

    test('write is NOT retried on transient failure', () async {
      final rec = _RecordingReporter();
      var calls = 0;
      await expectLater(
        _run(rec.reporter, writeCallHeaders(), (req) async {
          calls++;
          throw connect.ConnectException(connect.Code.unavailable, 'blip');
        }),
        throwsA(isA<connect.ConnectException>()),
      );
      expect(calls, 1, reason: 'writes never auto-retry in step 5');
      expect(rec.failures, [FailureKind.transient]);
    });

    test('timeout → deadlineExceeded + transient failure', () async {
      final rec = _RecordingReporter();
      await expectLater(
        _run(rec.reporter, writeCallHeaders(deadline: const Duration(milliseconds: 20)),
            (req) => Completer<connect.Response<Object, Object>>().future),
        throwsA(isA<connect.ConnectException>().having(
            (e) => e.code, 'code', connect.Code.deadlineExceeded)),
      );
      expect(rec.failures, contains(FailureKind.transient));
    });

    test('internal headers are stripped before hitting the wire', () async {
      final rec = _RecordingReporter();
      late connect.Headers seen;
      await _run(rec.reporter, readCallHeaders(), (req) async {
        seen = req.headers;
        return _resp(req.spec);
      });
      expect(seen.contains('x-pos-retry'), isFalse);
      expect(seen.contains('x-pos-deadline-ms'), isFalse);
    });
  });
}
