/// Connection-health aggregator (docs/desktop-connection-resilience.md §3).
///
/// The single sink for reachability signals. Three sources feed it:
///   1. RPC outcomes — via [ConnectionHealthController.recordSuccess] /
///      [recordFailure], called by the resilience interceptor (rpc_policy).
///   2. The realtime channel's connect/disconnect edges — free liveness.
///   3. An idle `/healthz` probe on backoff, active only while NOT reachable.
///
/// Built lazily: the transport interceptor reads the notifier only when an
/// RPC actually fires, and the nav-shell chip watches it — so tests that
/// don't touch either never spin up the probe. Tests that do should override
/// [healthProbeProvider] (and [clockProvider]) for determinism.
library;

import 'dart:async';
import 'dart:io';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config.dart';
import '../domain/connection_health.dart';
import 'backoff.dart';
import 'realtime.dart';

part 'connection_health_provider.g.dart';

/// Injectable clock so `lastOkAt` is deterministic in tests.
@Riverpod(keepAlive: true)
DateTime Function() clock(ClockRef ref) => DateTime.now;

/// A one-shot reachability probe: `true` iff `GET {serverUrl}/healthz` → 200.
typedef HealthProbe = Future<bool> Function(String serverUrl);

/// Default probe over a short-lived dart:io client. Any error → `false`
/// (unreachable); never throws.
Future<bool> defaultHealthProbe(String serverUrl) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 2);
  try {
    final req = await client.getUrl(Uri.parse('$serverUrl/healthz'));
    final resp = await req.close().timeout(const Duration(seconds: 2));
    await resp.drain<void>();
    return resp.statusCode == 200;
  } catch (_) {
    return false;
  } finally {
    client.close(force: true);
  }
}

@Riverpod(keepAlive: true)
HealthProbe healthProbe(HealthProbeRef ref) => defaultHealthProbe;

/// The aggregator. Public [recordSuccess]/[recordFailure] are the RPC hooks;
/// the realtime listener and probe are wired internally.
@Riverpod(keepAlive: true)
class ConnectionHealthController extends _$ConnectionHealthController {
  Timer? _probeTimer;
  Backoff? _probeBackoff;
  bool _disposed = false;

  @override
  ConnectionHealth build() {
    final ch = ref.watch(realtimeChannelProvider);
    final sub = ch.connected.listen((up) {
      if (up) {
        _onServerAnswered();
      } else {
        _onRealtimeDropped();
      }
    });
    ref.onDispose(() {
      _disposed = true;
      sub.cancel();
      _probeTimer?.cancel();
      _probeTimer = null;
    });

    // Start optimistically-unproven and probe until the first confirmation.
    _scheduleProbe();
    return ConnectionHealth.initial();
  }

  /// Any server answer (RPC success, or a server-returned business/auth
  /// error) confirms reachability.
  void recordSuccess() => _onServerAnswered();

  /// A transport-level failure. Applies the §6-Q6.3 rule:
  /// refused ⇒ unreachable immediately; transient ⇒ unreachable after 2.
  void recordFailure(FailureKind kind, String summary) {
    final fails = state.consecutiveFailures + 1;
    final ServerReachability next;
    if (kind == FailureKind.refused) {
      next = ServerReachability.unreachable;
    } else {
      next = fails >= 2
          ? ServerReachability.unreachable
          : ServerReachability.degraded;
    }
    state = state.copyWith(
      state: next,
      consecutiveFailures: fails,
      lastErrorSummary: summary,
    );
    _syncProbe();
  }

  void _onServerAnswered() {
    state = ConnectionHealth(
      state: ServerReachability.reachable,
      consecutiveFailures: 0,
      lastOkAt: ref.read(clockProvider)(),
    );
    _syncProbe();
  }

  void _onRealtimeDropped() {
    // A dropped WebSocket is not an RPC failure — soften reachable→degraded
    // and let the probe / next RPC confirm. Never jump to unreachable on the
    // WS edge alone (RPC is the authority for "confirmed down").
    if (state.state == ServerReachability.reachable) {
      state = state.copyWith(state: ServerReachability.degraded);
      _syncProbe();
    }
  }

  void _syncProbe() {
    if (state.state == ServerReachability.reachable) {
      _probeTimer?.cancel();
      _probeTimer = null;
      _probeBackoff = null; // reset so the next outage probes fast again.
    } else {
      _scheduleProbe();
    }
  }

  void _scheduleProbe() {
    if (_disposed || _probeTimer != null) return;
    _probeBackoff ??= Backoff(
      initial: const Duration(seconds: 1),
      max: const Duration(seconds: 15),
    );
    _probeTimer = Timer(_probeBackoff!.next(), _runProbe);
  }

  Future<void> _runProbe() async {
    _probeTimer = null;
    if (_disposed) return;
    final serverUrl = ref.read(terminalConfigProvider).serverUrl;
    final ok = await ref.read(healthProbeProvider)(serverUrl);
    if (_disposed) return;
    if (ok) {
      _onServerAnswered();
    } else {
      // A failed probe can't tell refused from slow — treat as transient.
      // recordFailure reschedules via _syncProbe.
      recordFailure(FailureKind.transient, 'health probe failed');
    }
  }
}
