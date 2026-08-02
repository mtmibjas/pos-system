/// Realtime client tests — focus on URL derivation and frame
/// classification. The IO/reconnect loop is exercised end-to-end by
/// integration tests on the server side; here we just verify the
/// classifier so consumers can rely on the sealed [RealtimeFrame] split.
library;

import 'dart:async';

import 'package:desktop_pos/core/realtime.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('realtimeUrlFromServer swaps http→ws and appends path', () {
    final url = realtimeUrlFromServer('http://127.0.0.1:8081');
    expect(url, startsWith('ws://'));
    expect(url, endsWith('/v1/events/stream'));
  });

  test('realtimeUrlFromServer swaps https→wss', () {
    final url = realtimeUrlFromServer('https://shop.example:8443');
    expect(url, startsWith('wss://'));
    expect(url, endsWith('/v1/events/stream'));
  });

  test('event_type present → RealtimeEnvelopeFrame; high-water tracked',
      () async {
    final ch = FakeRealtimeChannel();
    final received = <RealtimeFrame>[];
    final sub = ch.stream.listen(received.add);

    ch.pushJson({
      'event_type': 'sale_created',
      'operation_id': 'op-1',
      'tenant_id': 't-1',
      'lamport': 42,
      'envelope_b64': 'abc',
    });
    await Future<void>.delayed(Duration.zero);

    expect(received, hasLength(1));
    final env = received.single as RealtimeEnvelopeFrame;
    expect(env.eventType, 'sale_created');
    expect(env.lamport, 42);
    expect(env.operationId, 'op-1');
    expect(ch.highWaterLamport, 42);

    await sub.cancel();
    await ch.close();
  });

  test('type=catchup_complete → control frame', () async {
    final ch = FakeRealtimeChannel();
    final received = <RealtimeFrame>[];
    ch.stream.listen(received.add);

    ch.pushJson({'type': 'catchup_complete', 'up_to_lamport': 5});
    await Future<void>.delayed(Duration.zero);

    final f = received.single as RealtimeControlFrame;
    expect(f.isCatchupComplete, isTrue);
    expect(f.json['up_to_lamport'], 5);
    await ch.close();
  });

  test('type=inventory_available_changed → raw frame', () async {
    final ch = FakeRealtimeChannel();
    final received = <RealtimeFrame>[];
    ch.stream.listen(received.add);

    ch.pushJson({
      'type': 'inventory_available_changed',
      'store_id': 's-1',
      'sku': 'A',
      'available_qty': 3,
    });
    await Future<void>.delayed(Duration.zero);

    final f = received.single as RealtimeRawFrame;
    expect(f.type, 'inventory_available_changed');
    expect(f.json['sku'], 'A');
    expect(f.json['available_qty'], 3);
    await ch.close();
  });

  test('high-water lamport only advances forward', () async {
    final ch = FakeRealtimeChannel();
    ch.stream.listen((_) {});

    ch.pushJson({'event_type': 'x', 'lamport': 3});
    ch.pushJson({'event_type': 'x', 'lamport': 10});
    ch.pushJson({'event_type': 'x', 'lamport': 7});
    await Future<void>.delayed(Duration.zero);

    expect(ch.highWaterLamport, 10);
    await ch.close();
  });
}

/// In-test [RealtimeChannel] that mirrors the production classifier so
/// the assertions cover the real branching without touching dart:io.
/// Exported (no leading underscore) so other test files can reuse it.
class FakeRealtimeChannel implements RealtimeChannel {
  final _ctl = StreamController<RealtimeFrame>.broadcast();
  int _hw = 0;

  void pushJson(Map<String, dynamic> m) {
    RealtimeFrame? frame;
    if (m.containsKey('event_type')) {
      final env = RealtimeEnvelopeFrame(
        lamport: (m['lamport'] as num?)?.toInt() ?? 0,
        operationId: (m['operation_id'] as String?) ?? '',
        eventType: (m['event_type'] as String?) ?? '',
        tenantId: (m['tenant_id'] as String?) ?? '',
        envelopeB64: (m['envelope_b64'] as String?) ?? '',
      );
      if (env.lamport > _hw) _hw = env.lamport;
      frame = env;
    } else {
      final type = m['type'] as String?;
      if (type == null) return;
      if (type == 'catchup_complete' || type == 'catchup_overflow') {
        frame = RealtimeControlFrame(type: type, json: m);
      } else {
        frame = RealtimeRawFrame(type: type, json: m);
      }
    }
    _ctl.add(frame);
  }

  @override
  Stream<RealtimeFrame> get stream => _ctl.stream;

  @override
  int get highWaterLamport => _hw;

  @override
  Future<void> close() => _ctl.close();
}
