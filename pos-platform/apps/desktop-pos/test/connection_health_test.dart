/// Unit tests for the connection-health aggregator
/// (connection_health_provider.dart). Transitions are driven synchronously
/// via the public record* hooks and the realtime connect/disconnect edges;
/// the idle probe is overridden so tests stay deterministic.
library;

import 'package:desktop_pos/core/connection_health_provider.dart';
import 'package:desktop_pos/core/realtime.dart';
import 'package:desktop_pos/domain/connection_health.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'realtime_test.dart' show FakeRealtimeChannel;

void main() {
  final fixedNow = DateTime.utc(2026, 8, 2, 12);

  ({ProviderContainer container, FakeRealtimeChannel ws}) harness() {
    final ws = FakeRealtimeChannel();
    final container = ProviderContainer(overrides: [
      realtimeChannelProvider.overrideWithValue(ws),
      clockProvider.overrideWithValue(() => fixedNow),
      // Probe stays "down" so a stray timer never flips state under test.
      healthProbeProvider.overrideWithValue((_) async => false),
    ]);
    addTearDown(container.dispose);
    return (container: container, ws: ws);
  }

  ConnectionHealth stateOf(ProviderContainer c) =>
      c.read(connectionHealthControllerProvider);
  ConnectionHealthController notifierOf(ProviderContainer c) =>
      c.read(connectionHealthControllerProvider.notifier);

  test('starts degraded (optimistic-unproven)', () {
    final h = harness();
    expect(stateOf(h.container).state, ServerReachability.degraded);
    expect(stateOf(h.container).lastOkAt, isNull);
  });

  test('success → reachable, stamps lastOkAt, resets failures', () {
    final h = harness();
    final n = notifierOf(h.container);
    n.recordFailure(FailureKind.transient, 'blip');
    n.recordSuccess();
    final s = stateOf(h.container);
    expect(s.state, ServerReachability.reachable);
    expect(s.consecutiveFailures, 0);
    expect(s.lastOkAt, fixedNow);
  });

  test('one transient failure → degraded; second → unreachable', () {
    final h = harness();
    final n = notifierOf(h.container);
    n.recordFailure(FailureKind.transient, 'blip');
    expect(stateOf(h.container).state, ServerReachability.degraded);
    expect(stateOf(h.container).consecutiveFailures, 1);
    n.recordFailure(FailureKind.transient, 'blip');
    expect(stateOf(h.container).state, ServerReachability.unreachable);
    expect(stateOf(h.container).consecutiveFailures, 2);
  });

  test('refused → unreachable immediately', () {
    final h = harness();
    notifierOf(h.container).recordFailure(FailureKind.refused, 'ECONNREFUSED');
    expect(stateOf(h.container).state, ServerReachability.unreachable);
  });

  test('recovery from unreachable → reachable on next success', () {
    final h = harness();
    final n = notifierOf(h.container);
    n.recordFailure(FailureKind.refused, 'down');
    expect(stateOf(h.container).state, ServerReachability.unreachable);
    n.recordSuccess();
    expect(stateOf(h.container).state, ServerReachability.reachable);
  });

  test('WS connect edge confirms reachable', () async {
    final h = harness();
    notifierOf(h.container); // force build so it listens
    h.ws.pushConnected(true);
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(h.container).state, ServerReachability.reachable);
  });

  test('WS drop softens reachable→degraded, never straight to unreachable',
      () async {
    final h = harness();
    final n = notifierOf(h.container);
    n.recordSuccess(); // reachable
    h.ws.pushConnected(false);
    await Future<void>.delayed(Duration.zero);
    expect(stateOf(h.container).state, ServerReachability.degraded);
  });
}
