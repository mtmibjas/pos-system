/// Local SQLite persistence adapter (docs/desktop-local-persistence.md §2).
///
/// Backs TerminalConfig, the in-progress cart draft, and the single pending
/// finalize (the bounded ambiguous-response retry). Desktop uses
/// `sqflite_common_ffi` (`databaseFactoryFfi`) since plain `sqflite` is
/// mobile-only — same SQL/API, Windows + macOS capable.
///
/// The session TOKEN never lives here — it stays in flutter_secure_storage
/// (§4.2). SQLite holds only non-secret operational state.
///
/// Tests override [appDatabaseProvider] with an in-memory database
/// ([openInMemoryDatabase]) so the whole persistence layer runs with no files
/// and no server, preserving the app's testability property.
library;

import 'package:path_provider/path_provider.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'local_db.g.dart';

/// Current schema version. Bump + extend [_migrate] when adding tables.
const int kLocalDbVersion = 1;

/// Creates the full schema on a fresh database.
Future<void> _onCreate(Database db, int version) async {
  final batch = db.batch();

  // Single-row terminal config (id pinned to 1). Written by provisioning
  // (step 7); read by terminalConfigProvider with a defaults fallback.
  batch.execute('''
    CREATE TABLE terminal_config (
      id           INTEGER PRIMARY KEY CHECK (id = 1),
      server_url   TEXT NOT NULL,
      store_id     TEXT NOT NULL,
      counter_id   TEXT NOT NULL,
      terminal_name TEXT NOT NULL
    )
  ''');

  // One open cart draft per (store, counter). sale_id is the STABLE
  // idempotency key minted when the draft opens (§5.2) so a finalize retry
  // replays the same sale server-side.
  batch.execute('''
    CREATE TABLE cart_draft (
      store_id   TEXT NOT NULL,
      counter_id TEXT NOT NULL,
      sale_id    TEXT,
      updated_at TEXT NOT NULL,
      PRIMARY KEY (store_id, counter_id)
    )
  ''');

  batch.execute('''
    CREATE TABLE cart_draft_line (
      store_id        TEXT NOT NULL,
      counter_id      TEXT NOT NULL,
      position        INTEGER NOT NULL,
      sku             TEXT NOT NULL,
      description     TEXT NOT NULL,
      currency_code   TEXT NOT NULL,
      units           INTEGER NOT NULL,
      nanos           INTEGER NOT NULL,
      tax_category_id TEXT NOT NULL,
      quantity        INTEGER NOT NULL,
      PRIMARY KEY (store_id, counter_id, position)
    )
  ''');

  // At most ONE pending finalize per (store, counter) — the bounded
  // reconnect-retry of a single in-flight write (§5.3). NOT an offline queue.
  batch.execute('''
    CREATE TABLE pending_finalize (
      store_id     TEXT NOT NULL,
      counter_id   TEXT NOT NULL,
      sale_id      TEXT NOT NULL,
      request_json TEXT NOT NULL,
      created_at   TEXT NOT NULL,
      PRIMARY KEY (store_id, counter_id)
    )
  ''');

  await batch.commit(noResult: true);
}

Future<void> _onUpgrade(Database db, int from, int to) async {
  // v1 is the initial schema; no upgrades yet. Future versions append here.
}

/// Opens (and migrates) the on-disk database at [path] using the ffi factory.
Future<Database> openAppDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: kLocalDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    ),
  );
}

/// Opens a throwaway in-memory database with the same schema — for tests.
Future<Database> openInMemoryDatabase() {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    inMemoryDatabasePath,
    options: OpenDatabaseOptions(
      version: kLocalDbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    ),
  );
}

/// The shared application database. Opened once (keepAlive) at the OS
/// app-support dir. Tests override this with [openInMemoryDatabase].
@Riverpod(keepAlive: true)
Future<Database> appDatabase(AppDatabaseRef ref) async {
  final dir = await getApplicationSupportDirectory();
  final db = await openAppDatabase('${dir.path}/pos_desktop.db');
  ref.onDispose(db.close);
  return db;
}
