// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'hardware_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$escPosTransportHash() => r'c5ed8f548ae16760ea0c00b4520d680dfa0fe301';

/// The shared ESC/POS byte sink (printer + drawer chain off it), or null when
/// the terminal has no real printer configured.
///
/// Copied from [escPosTransport].
@ProviderFor(escPosTransport)
final escPosTransportProvider = Provider<EscPosTransport?>.internal(
  escPosTransport,
  name: r'escPosTransportProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$escPosTransportHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef EscPosTransportRef = ProviderRef<EscPosTransport?>;
String _$receiptPrinterHash() => r'9b1024b18b770e7d8caba7d280aa497219a98375';

/// See also [receiptPrinter].
@ProviderFor(receiptPrinter)
final receiptPrinterProvider = Provider<ReceiptPrinter>.internal(
  receiptPrinter,
  name: r'receiptPrinterProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$receiptPrinterHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef ReceiptPrinterRef = ProviderRef<ReceiptPrinter>;
String _$cashDrawerHash() => r'33f00a98ed2ac404cf811d536241aebfa30de424';

/// See also [cashDrawer].
@ProviderFor(cashDrawer)
final cashDrawerProvider = Provider<CashDrawer>.internal(
  cashDrawer,
  name: r'cashDrawerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$cashDrawerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CashDrawerRef = ProviderRef<CashDrawer>;
String _$barcodeScannerHash() => r'2bfbbc7eb8c160943476c5800d7042ba489b6bec';

/// See also [barcodeScanner].
@ProviderFor(barcodeScanner)
final barcodeScannerProvider = Provider<BarcodeScanner>.internal(
  barcodeScanner,
  name: r'barcodeScannerProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$barcodeScannerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef BarcodeScannerRef = ProviderRef<BarcodeScanner>;
String _$customerDisplayHash() => r'79dfdfe93178efb0d0b8be7dcd245e4ea4ab6af8';

/// See also [customerDisplay].
@ProviderFor(customerDisplay)
final customerDisplayProvider = Provider<CustomerDisplay>.internal(
  customerDisplay,
  name: r'customerDisplayProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$customerDisplayHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef CustomerDisplayRef = ProviderRef<CustomerDisplay>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
