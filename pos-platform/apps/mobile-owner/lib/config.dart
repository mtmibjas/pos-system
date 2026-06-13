/// Compile-time defaults for the mobile-owner client.
///
/// Runtime values (current server URL, current auth session) are held
/// in Riverpod providers and persisted to SharedPreferences /
/// secure_storage respectively. The constants here are only used as
/// first-launch seeds.
library;

/// Default cloud-api base URL — used on first launch before the
/// settings screen has written a custom value to SharedPreferences.
///
/// :18080 (not :8080) matches docs/local-env-setup.md — on the dev
/// machine Docker Desktop squats on :8080, so cloud-api runs on
/// :18080. Editable at runtime from the login/settings screens either
/// way.
const String kCloudApiUrl = 'http://127.0.0.1:18080';
