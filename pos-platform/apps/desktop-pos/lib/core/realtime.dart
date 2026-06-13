/// WebSocket realtime fan-in for the desktop POS client.
///
/// Phase 4 Slice 4.5. Counter UIs (inventory tile, item picker, cart)
/// subscribe to a single shared websocket so they react to events
/// originating on OTHER counters in the same store. The connection is
/// owned by [realtimeChannelProvider] (keepAlive) so it survives screen
/// navigation; reconnect-with-backoff is automatic, and the highest
/// lamport seen is replayed on each reconnect so no envelope is missed.
///
/// Wire format (matches local-store-server/internal/api/events_stream.go):
///
///   - Typed envelope (durable, in opslog): JSON object with
///     `event_type` — surfaced as [RealtimeEnvelopeFrame].
///   - Raw ad-hoc frame (intra-store ephemera, e.g.
///     inventory_available_changed): JSON object with `type` ≠ control —
///     surfaced as [RealtimeRawFrame].
///   - Control frame: `type` ∈ {catchup_complete, catchup_overflow} —
///     surfaced as [RealtimeControlFrame]. Subscribers may use these to
///     trigger a snapshot refresh after an overflow.
///
/// Tests override [realtimeChannelProvider] with a fake that pushes
/// frames into the broadcast stream directly — no WS needed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config.dart';

part 'realtime.g.dart';

/// Parent type for every frame surfaced by [RealtimeChannel.stream].
sealed class RealtimeFrame {
  const RealtimeFrame();
}

/// A typed posv1.EventEnvelope frame — `event_type` present. Carries the
/// top-level routing fields decoded from the wire JSON; the base64
/// envelope payload is included for callers that need the full proto
/// (none today on the Flutter side — controllers route on event_type).
@immutable
class RealtimeEnvelopeFrame extends RealtimeFrame {
  const RealtimeEnvelopeFrame({
    required this.lamport,
    required this.operationId,
    required this.eventType,
    required this.tenantId,
    required this.envelopeB64,
  });

  final int lamport;
  final String operationId;
  final String eventType;
  final String tenantId;
  final String envelopeB64;
}

/// A pre-encoded JSON frame for intra-store ephemera (slice 4.3:
/// inventory_available_changed). The raw decoded JSON map is exposed so
/// each consumer reads only the keys it cares about.
@immutable
class RealtimeRawFrame extends RealtimeFrame {
  const RealtimeRawFrame({required this.type, required this.json});
  final String type;
  final Map<String, dynamic> json;
}

/// Server-emitted control frame (slice 4.4). [type] is one of
/// "catchup_complete" or "catchup_overflow". [json] carries the rest
/// of the payload (e.g. up_to_lamport, since_lamport, max_replay).
@immutable
class RealtimeControlFrame extends RealtimeFrame {
  const RealtimeControlFrame({required this.type, required this.json});
  final String type;
  final Map<String, dynamic> json;

  bool get isCatchupComplete => type == 'catchup_complete';
  bool get isCatchupOverflow => type == 'catchup_overflow';
}

/// Single connection point shared across controllers. Exposes a
/// broadcast [stream] of [RealtimeFrame]s. Closing happens implicitly
/// when the provider is disposed (process shutdown).
abstract class RealtimeChannel {
  Stream<RealtimeFrame> get stream;

  /// The highest envelope lamport we've delivered. Useful for tests;
  /// production reconnect uses this internally.
  int get highWaterLamport;

  /// Tear down the underlying connection and stop reconnecting.
  Future<void> close();
}

/// Default URL derivation: swap http://→ws:// (and https→wss) on the
/// configured local server, then append the events-stream path. Kept
/// here (not in config.dart) because the path itself belongs to the
/// realtime feature.
String defaultRealtimeUrl() {
  var url = kLocalServerUrl;
  if (url.startsWith('http://')) {
    url = 'ws://${url.substring('http://'.length)}';
  } else if (url.startsWith('https://')) {
    url = 'wss://${url.substring('https://'.length)}';
  }
  // Path mirrors EventsStreamPath in events_stream.go.
  return '$url/v1/events/stream';
}

/// Production [RealtimeChannel] backed by `dart:io` [WebSocket]. Manages
/// its own reconnect loop with exponential backoff (1s → 30s capped).
class IoRealtimeChannel implements RealtimeChannel {
  IoRealtimeChannel({
    String? url,
    Duration initialBackoff = const Duration(seconds: 1),
    Duration maxBackoff = const Duration(seconds: 30),
  })  : _url = url ?? defaultRealtimeUrl(),
        _initialBackoff = initialBackoff,
        _maxBackoff = maxBackoff {
    _runLoop();
  }

  final String _url;
  final Duration _initialBackoff;
  final Duration _maxBackoff;
  final StreamController<RealtimeFrame> _ctl =
      StreamController<RealtimeFrame>.broadcast();
  WebSocket? _ws;
  bool _closed = false;
  int _highWater = 0;

  @override
  Stream<RealtimeFrame> get stream => _ctl.stream;

  @override
  int get highWaterLamport => _highWater;

  @override
  Future<void> close() async {
    _closed = true;
    try {
      await _ws?.close();
    } catch (_) {
      // best-effort
    }
    await _ctl.close();
  }

  Future<void> _runLoop() async {
    var backoff = _initialBackoff;
    while (!_closed) {
      try {
        // On reconnect, request a replay from the highest lamport we've
        // already delivered. since_lamport=0 on first connect means
        // "replay everything from scratch" per the server contract.
        final uri = Uri.parse('$_url?since_lamport=$_highWater');
        final ws = await WebSocket.connect(uri.toString());
        _ws = ws;
        backoff = _initialBackoff; // reset on successful connect.
        await for (final raw in ws) {
          if (raw is! String) continue;
          final decoded = _safeDecode(raw);
          if (decoded == null) continue;
          final frame = _classify(decoded);
          if (frame == null) continue;
          if (frame is RealtimeEnvelopeFrame && frame.lamport > _highWater) {
            _highWater = frame.lamport;
          }
          if (!_ctl.isClosed) _ctl.add(frame);
        }
      } catch (_) {
        // Connection error or unexpected close — fall through to backoff.
      }
      _ws = null;
      if (_closed) break;
      await Future<void>.delayed(backoff);
      // Exponential with jitter to avoid thundering-herd if many counters
      // wake at the same time after a power blip.
      final next = backoff * 2;
      backoff = next > _maxBackoff ? _maxBackoff : next;
      final jitterMs = Random().nextInt(250);
      backoff += Duration(milliseconds: jitterMs);
      if (backoff > _maxBackoff) backoff = _maxBackoff;
    }
  }

  Map<String, dynamic>? _safeDecode(String s) {
    try {
      final v = jsonDecode(s);
      if (v is Map<String, dynamic>) return v;
    } catch (_) {}
    return null;
  }

  RealtimeFrame? _classify(Map<String, dynamic> m) {
    // Typed envelope frames carry `event_type`. Everything else uses
    // `type` to discriminate between control frames (catchup_*) and
    // raw ad-hoc frames (e.g. inventory_available_changed).
    if (m.containsKey('event_type')) {
      return RealtimeEnvelopeFrame(
        lamport: (m['lamport'] as num?)?.toInt() ?? 0,
        operationId: (m['operation_id'] as String?) ?? '',
        eventType: (m['event_type'] as String?) ?? '',
        tenantId: (m['tenant_id'] as String?) ?? '',
        envelopeB64: (m['envelope_b64'] as String?) ?? '',
      );
    }
    final type = m['type'] as String?;
    if (type == null) return null;
    if (type == 'catchup_complete' || type == 'catchup_overflow') {
      return RealtimeControlFrame(type: type, json: m);
    }
    return RealtimeRawFrame(type: type, json: m);
  }
}

/// keepAlive so a single socket survives navigation. Disposed only when
/// the ProviderContainer is torn down (app exit).
@Riverpod(keepAlive: true)
RealtimeChannel realtimeChannel(RealtimeChannelRef ref) {
  final ch = IoRealtimeChannel();
  ref.onDispose(() => ch.close());
  return ch;
}
