/// Persistence for [TerminalConfig] (docs/desktop-local-persistence.md §2).
///
/// 6a adds the read/save path only. The provisioning flow (step 7) calls
/// [save]; `terminalConfigProvider` is rewired to prefer the persisted row
/// there. Until a row is written, [load] returns null and the app keeps its
/// hardcoded defaults — no behavior change this slice.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../config.dart';
import 'local_db.dart';

part 'terminal_config_store.g.dart';

class TerminalConfigStore {
  TerminalConfigStore(this._db);

  final Future<Database> _db;

  /// The single persisted config, or null if the terminal is unprovisioned.
  Future<TerminalConfig?> load() async {
    final db = await _db;
    final rows = await db.query('terminal_config', where: 'id = 1', limit: 1);
    if (rows.isEmpty) return null;
    final r = rows.first;
    return TerminalConfig(
      serverUrl: r['server_url']! as String,
      storeId: r['store_id']! as String,
      counterId: r['counter_id']! as String,
      terminalName: r['terminal_name']! as String,
    );
  }

  /// Upserts the single config row (id pinned to 1).
  Future<void> save(TerminalConfig cfg) async {
    final db = await _db;
    await db.insert(
      'terminal_config',
      {
        'id': 1,
        'server_url': cfg.serverUrl,
        'store_id': cfg.storeId,
        'counter_id': cfg.counterId,
        'terminal_name': cfg.terminalName,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

@Riverpod(keepAlive: true)
TerminalConfigStore terminalConfigStore(TerminalConfigStoreRef ref) =>
    TerminalConfigStore(ref.watch(appDatabaseProvider.future));
