/// Hardware port providers + the single selection factory
/// (docs/desktop-hardware-ports.md §3). Features depend on these providers,
/// never on a concrete adapter. Selection is driven by `TerminalConfig`
/// (+ OS detection later); tests override the providers with sim adapters.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../config.dart';
import 'esc_pos.dart';
import 'noop_adapters.dart';
import 'ports.dart';

part 'hardware_providers.g.dart';

/// A parsed `network:HOST:PORT` target.
typedef PrinterEndpoint = ({String host, int port});

/// Parse a [TerminalConfig.printerTarget]. Returns null for `noop`, an empty
/// value, or anything malformed — the factory falls back to Noop (never
/// throws, per §8).
PrinterEndpoint? parsePrinterTarget(String target) {
  if (!target.startsWith('network:')) return null;
  final rest = target.substring('network:'.length);
  final i = rest.lastIndexOf(':');
  if (i <= 0 || i == rest.length - 1) return null;
  final host = rest.substring(0, i);
  final port = int.tryParse(rest.substring(i + 1));
  if (port == null || port <= 0 || port > 65535) return null;
  return (host: host, port: port);
}

/// The shared ESC/POS byte sink (printer + drawer chain off it), or null when
/// the terminal has no real printer configured.
@Riverpod(keepAlive: true)
EscPosTransport? escPosTransport(EscPosTransportRef ref) {
  final target = ref.watch(terminalConfigProvider).printerTarget;
  final ep = parsePrinterTarget(target);
  if (ep == null) return null;
  return NetworkEscPosTransport(ep.host, ep.port);
}

/// A `file:PATH` spool target, or null if [target] isn't a file target.
String? parseFileTarget(String target) {
  if (!target.startsWith('file:')) return null;
  final path = target.substring('file:'.length);
  return path.isEmpty ? null : path;
}

@Riverpod(keepAlive: true)
ReceiptPrinter receiptPrinter(ReceiptPrinterRef ref) {
  final target = ref.watch(terminalConfigProvider).printerTarget;
  final filePath = parseFileTarget(target);
  if (filePath != null) return FileReceiptPrinter(filePath);
  final t = ref.watch(escPosTransportProvider);
  return t == null ? const NoopReceiptPrinter() : EscPosReceiptPrinter(t);
}

@Riverpod(keepAlive: true)
CashDrawer cashDrawer(CashDrawerRef ref) {
  final t = ref.watch(escPosTransportProvider);
  return t == null ? const NoopCashDrawer() : EscPosCashDrawer(t);
}

@Riverpod(keepAlive: true)
BarcodeScanner barcodeScanner(BarcodeScannerRef ref) {
  final s = WedgeBarcodeScanner();
  ref.onDispose(s.dispose);
  return s;
}

@Riverpod(keepAlive: true)
CustomerDisplay customerDisplay(CustomerDisplayRef ref) =>
    const NoopCustomerDisplay();
