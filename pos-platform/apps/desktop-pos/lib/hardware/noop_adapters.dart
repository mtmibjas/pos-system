/// Noop / simulated hardware adapters (docs/desktop-hardware-ports.md §1).
///
/// Every port has one so the app runs and is testable with no hardware. The
/// capturing/simulated variants double as test doubles.
library;

import 'dart:async';

import '../features/items/scan_buffer.dart';
import 'ports.dart';
import 'receipt_document.dart';

/// Silently succeeds — the default on an unconfigured terminal.
class NoopReceiptPrinter implements ReceiptPrinter {
  const NoopReceiptPrinter();
  @override
  Future<void> printReceipt(ReceiptDocument doc) async {}
}

/// Records printed documents — tests + a dev "last receipt" preview.
class CapturingReceiptPrinter implements ReceiptPrinter {
  final List<ReceiptDocument> printed = [];

  @override
  Future<void> printReceipt(ReceiptDocument doc) async => printed.add(doc);

  ReceiptDocument? get last => printed.isEmpty ? null : printed.last;
}

class NoopCashDrawer implements CashDrawer {
  const NoopCashDrawer();
  @override
  Future<void> kick() async {}
}

class NoopCustomerDisplay implements CustomerDisplay {
  const NoopCustomerDisplay();
  @override
  Future<void> showLines(List<String> lines) async {}
  @override
  Future<void> clear() async {}
}

/// Test/dev scanner — push completed scans directly, no keyboard.
class SimulatedScanner implements BarcodeScanner {
  final StreamController<String> _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get scans => _ctl.stream;

  /// Emit a completed scan as if the hardware had fired.
  void emit(String payload) {
    if (!_ctl.isClosed) _ctl.add(payload);
  }

  @override
  void feedChar(String ch) {}
  @override
  void terminate() {}
  @override
  void reset() {}

  Future<void> dispose() => _ctl.close();
}

/// Default HID adapter: a keyboard-wedge scanner backed by the existing
/// `ScanBuffer` state machine. The widget layer feeds chars; completed scans
/// surface on [scans].
class WedgeBarcodeScanner implements BarcodeScanner {
  WedgeBarcodeScanner({ScanBuffer? buffer}) : _buffer = buffer ?? ScanBuffer();

  final ScanBuffer _buffer;
  final StreamController<String> _ctl = StreamController<String>.broadcast();

  @override
  Stream<String> get scans => _ctl.stream;

  @override
  void feedChar(String ch) {
    // The port tolerates stray non-single-char input; ScanBuffer would throw.
    if (ch.length == 1) _buffer.add(ch);
  }

  @override
  void terminate() {
    final payload = _buffer.commit();
    if (payload.isNotEmpty && !_ctl.isClosed) _ctl.add(payload);
  }

  @override
  void reset() => _buffer.reset();

  Future<void> dispose() => _ctl.close();
}
