/// Compile-time configuration for the desktop POS client.
///
/// Phase 2 Half B keeps the local-store-server URL hardcoded
/// (see memory: project_phase2b_decisions.md). When mDNS / a settings
/// screen lands, this const becomes a Riverpod Provider sourced from
/// persistent settings — the transport provider in core/transport.dart
/// is already wired to swap to a Provider without touching screens.
library;

const String kLocalServerUrl = 'http://127.0.0.1:8081';

// --- Identity placeholders (Slice 2.9) ------------------------------------
//
// No login / station-provisioning flow exists yet. SaleService.Finalize
// still requires store/counter/cashier identifiers in its request, so
// we ship constants. These become real values when the provisioning
// flow lands (Phase 3+).
const String kStoreId = 'store-1';
const String kCounterId = 'counter-1';
const String kCashierId = 'cashier-1';
