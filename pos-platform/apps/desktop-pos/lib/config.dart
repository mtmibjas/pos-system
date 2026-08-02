/// Per-terminal configuration for the desktop POS client.
///
/// This is the **config seam** (docs/desktop-architecture.md §6 step 1):
/// the Phase-2 hardcoded consts become a [TerminalConfig] exposed through a
/// Riverpod provider, so the transport, the realtime channel, and the
/// controllers all read the server URL + store/counter identity from ONE
/// overridable place. The defaults preserve the previous hardcoded values,
/// so this slice is a pure seam with NO behavior change.
///
/// Later slices source [terminalConfigProvider] from persisted per-terminal
/// provisioning (§4.1), and [cashierIdProvider] from the auth session
/// (§4.2 / §6 step 3) — at which point this file's defaults fall away.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config.g.dart';

/// Immutable per-terminal settings: where the store server is, and which
/// store + counter this terminal is.
///
/// `cashierId` is deliberately NOT here — it is operator identity, not
/// terminal identity. It lives in the auth feature's `cashierIdProvider`
/// (features/auth/session_controller.dart), derived from the session.
class TerminalConfig {
  const TerminalConfig({
    required this.serverUrl,
    required this.storeId,
    required this.counterId,
    required this.terminalName,
    this.printerTarget = 'noop',
  });

  final String serverUrl;
  final String storeId;
  final String counterId;
  final String terminalName;

  /// Receipt-printer adapter selector (docs/desktop-hardware-ports.md §3).
  /// `'noop'` (default), `'network:HOST:PORT'` (ESC/POS over TCP), or
  /// `'file:PATH'` (spool the ESC/POS bytes to a file). USB/serial later.
  final String printerTarget;
}

/// The active terminal config. Defaults to the Phase-2 values; overridden in
/// tests via `ProviderScope`, and (later) replaced by a provider that reads
/// persisted provisioning.
@Riverpod(keepAlive: true)
TerminalConfig terminalConfig(TerminalConfigRef ref) {
  return const TerminalConfig(
    serverUrl: 'http://127.0.0.1:8081',
    storeId: 'store-1',
    counterId: 'counter-1',
    terminalName: 'desktop-pos',
  );
}

