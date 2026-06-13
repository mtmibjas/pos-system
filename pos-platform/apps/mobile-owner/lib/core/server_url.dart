/// Editable cloud-api base URL.
///
/// Hardening item H5: the URL is no longer compile-time. It's seeded
/// from [kCloudApiUrl] on first launch, then persisted via
/// SharedPreferences so a UAT operator can repoint the app to a
/// different cloud-api without rebuilding.
///
/// Providers:
///   - [serverUrlProvider]      — current value; rebuilds whenever
///                                 settings_screen mutates it. Repositories
///                                 read this for their base URL.
///   - [serverUrlStoreProvider] — persistence shim; settings_screen
///                                 calls .save() to update prefs.
///
/// Both are overridden in main() after the SharedPreferences instance
/// has been awaited. The fallback bodies below let widget tests that
/// don't override them still resolve.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config.dart';

/// Pref key. Bumped only if the value schema changes.
const String kPrefServerUrl = 'cloud_api_url_v1';

/// Current cloud-api base URL. Default = compile-time seed.
final serverUrlProvider = StateProvider<Uri>((_) => Uri.parse(kCloudApiUrl));

/// Thin wrapper around SharedPreferences for the URL value only.
/// Kept narrow so settings_screen doesn't grow a prefs dependency.
class ServerUrlStore {
  ServerUrlStore(this._prefs);
  final SharedPreferences _prefs;

  /// Loads the persisted URL, falling back to [kCloudApiUrl] on missing/empty.
  /// Caller is responsible for catching FormatException if the stored value
  /// is corrupt — we don't silently reset because that hides bugs.
  Uri load() {
    final raw = _prefs.getString(kPrefServerUrl);
    if (raw == null || raw.isEmpty) return Uri.parse(kCloudApiUrl);
    return Uri.parse(raw);
  }

  Future<void> save(Uri url) =>
      _prefs.setString(kPrefServerUrl, url.toString());
}

/// Override with a real [ServerUrlStore] in main(). Tests that don't
/// touch settings can ignore this provider.
final serverUrlStoreProvider = Provider<ServerUrlStore>((_) {
  throw UnimplementedError(
      'serverUrlStoreProvider must be overridden in main()');
});
