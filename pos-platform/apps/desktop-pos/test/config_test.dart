/// Config-seam tests (docs/desktop-architecture.md §6 step 1).
///
/// The defaults must equal the previous Phase-2 hardcoded values (so the
/// seam is behavior-neutral), and the provider must be overridable — that
/// override point is what provisioning (§4.1) and auth (§4.2) plug into.
library;

import 'package:desktop_pos/config.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('default TerminalConfig preserves the Phase-2 values', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final cfg = c.read(terminalConfigProvider);
    expect(cfg.serverUrl, 'http://127.0.0.1:8081');
    expect(cfg.storeId, 'store-1');
    expect(cfg.counterId, 'counter-1');
    // cashierId moved to the auth feature (session-derived) — see
    // session_controller_test.dart.
  });

  test('terminalConfigProvider is overridable (the provisioning seam)', () {
    final c = ProviderContainer(overrides: [
      terminalConfigProvider.overrideWithValue(const TerminalConfig(
        serverUrl: 'http://192.168.1.50:8081',
        storeId: 'store-9',
        counterId: 'counter-3',
        terminalName: 'LAN till',
      )),
    ]);
    addTearDown(c.dispose);

    final cfg = c.read(terminalConfigProvider);
    expect(cfg.serverUrl, 'http://192.168.1.50:8081');
    expect(cfg.storeId, 'store-9');
    expect(cfg.counterId, 'counter-3');
    expect(cfg.terminalName, 'LAN till');
  });
}
