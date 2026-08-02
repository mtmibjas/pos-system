/// Domain model for store-server reachability
/// (docs/desktop-connection-resilience.md §2).
///
/// One health object describes "can this terminal talk to its store
/// server?" — a property of the single server process, not of individual
/// RPCs. The nav-shell status chip renders it (§5), and step 6 will gate
/// finalize on it (§4.7). Pure Dart, no Flutter/RPC imports — unit-testable
/// in isolation.
library;

import 'package:flutter/foundation.dart' show immutable;

/// The three honest reachability states. `degraded` is the middle ground:
/// a blip or an in-flight reconnect that we haven't yet confirmed as a real
/// outage — so we don't flash a scary "OFFLINE" on a single hiccup, but we
/// also don't claim health we can't prove.
enum ServerReachability { reachable, degraded, unreachable }

/// How a contact attempt failed — drives the degraded→unreachable decision
/// (§6 Q6.3: connection-refused ⇒ unreachable immediately; transient ⇒
/// unreachable after 2 consecutive).
enum FailureKind {
  /// TCP refused / socket error — the server is not answering at all.
  refused,

  /// Deadline exceeded or a transient `unavailable` — might be a slow blip.
  transient,
}

@immutable
class ConnectionHealth {
  const ConnectionHealth({
    required this.state,
    required this.consecutiveFailures,
    this.lastOkAt,
    this.lastErrorSummary,
  });

  /// Startup state: optimistic-but-unproven. We begin `degraded` (not
  /// `reachable`) so the very first successful call is what confirms health,
  /// and the idle probe runs until it does.
  factory ConnectionHealth.initial() => const ConnectionHealth(
        state: ServerReachability.degraded,
        consecutiveFailures: 0,
      );

  final ServerReachability state;
  final int consecutiveFailures;

  /// Last confirmed contact (any server answer, incl. business errors).
  final DateTime? lastOkAt;

  /// Human-readable last-failure note. Never contains secrets/credentials.
  final String? lastErrorSummary;

  bool get isReachable => state == ServerReachability.reachable;
  bool get isUnreachable => state == ServerReachability.unreachable;

  ConnectionHealth copyWith({
    ServerReachability? state,
    int? consecutiveFailures,
    DateTime? lastOkAt,
    String? lastErrorSummary,
  }) {
    return ConnectionHealth(
      state: state ?? this.state,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastOkAt: lastOkAt ?? this.lastOkAt,
      lastErrorSummary: lastErrorSummary ?? this.lastErrorSummary,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ConnectionHealth &&
      other.state == state &&
      other.consecutiveFailures == consecutiveFailures &&
      other.lastOkAt == lastOkAt &&
      other.lastErrorSummary == lastErrorSummary;

  @override
  int get hashCode =>
      Object.hash(state, consecutiveFailures, lastOkAt, lastErrorSummary);

  @override
  String toString() =>
      'ConnectionHealth($state, fails=$consecutiveFailures, ok=$lastOkAt)';
}
