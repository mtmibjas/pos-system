/// Hardware ports — the swappable interfaces every feature depends on
/// (docs/desktop-hardware-ports.md §1). No UI/controller talks to a driver
/// directly; only through these. Every port ships a Noop/simulated adapter
/// (see noop_adapters.dart) so the app runs hardware-free on the dev box.
library;

import 'receipt_document.dart';

/// Prints a rendered receipt. Failures throw; callers treat printing as a
/// non-critical side effect (a print failure must never fail a sale).
abstract class ReceiptPrinter {
  Future<void> printReceipt(ReceiptDocument doc);
}

/// Opens the cash drawer (real drawers chain off the printer's kick line).
abstract class CashDrawer {
  Future<void> kick();
}

/// Emits completed barcode scans. The HID adapter wraps `scan_buffer.dart`;
/// the widget layer feeds raw chars via [feedChar]/[terminate].
abstract class BarcodeScanner {
  /// Completed scans (payload per terminator).
  Stream<String> get scans;

  /// Feed one printable character (keyboard-wedge input).
  void feedChar(String ch);

  /// Terminator key received → emit the buffered scan (if any).
  void terminate();

  /// Discard any partial buffer (e.g. focus/context change).
  void reset();
}

/// Secondary customer-facing display. Noop-only this slice; a real
/// secondary-window adapter is deferred.
abstract class CustomerDisplay {
  Future<void> showLines(List<String> lines);
  Future<void> clear();
}
