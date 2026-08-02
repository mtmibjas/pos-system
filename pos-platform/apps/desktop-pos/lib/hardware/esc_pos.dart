/// Minimal, pure ESC/POS encoder + receipt renderer + transports
/// (docs/desktop-hardware-ports.md §4). Hand-rolled (decided) — no heavy
/// deps, every byte is unit-tested. Enough for a plain thermal receipt:
/// init, align, bold, text, feed, cut, drawer-kick.
library;

import 'dart:io';

import 'ports.dart';
import 'receipt_document.dart';

/// ESC/POS justification codes (ESC a n).
enum EscAlign { left, center, right }

/// Drawer pulse: ESC p m t1 t2 (pin 0, ~25 ms on / ~250 ms off).
const List<int> escPosKickBytes = [0x1B, 0x70, 0x00, 0x19, 0xFA];

/// Fluent byte builder. Immutable output via [bytes].
class EscPosEncoder {
  final List<int> _b = [];

  EscPosEncoder init() {
    _b.addAll(const [0x1B, 0x40]); // ESC @  — reset
    return this;
  }

  EscPosEncoder align(EscAlign a) {
    _b.addAll([0x1B, 0x61, a.index]); // ESC a n
    return this;
  }

  EscPosEncoder bold(bool on) {
    _b.addAll([0x1B, 0x45, on ? 1 : 0]); // ESC E n
    return this;
  }

  /// Appends text, mapping any rune > 0xFF to '?' (0x3F). ASCII/latin1 is
  /// enough for a minimal receipt; codepage handling comes with P7 if needed.
  EscPosEncoder text(String s) {
    for (final r in s.runes) {
      _b.add(r <= 0xFF ? r : 0x3F);
    }
    return this;
  }

  /// Text followed by a line feed (print + advance).
  EscPosEncoder line([String s = '']) {
    text(s);
    _b.add(0x0A);
    return this;
  }

  EscPosEncoder feed([int n = 1]) {
    _b.addAll([0x1B, 0x64, n]); // ESC d n
    return this;
  }

  EscPosEncoder cut() {
    _b.addAll(const [0x1D, 0x56, 0x00]); // GS V 0 — full cut
    return this;
  }

  EscPosEncoder kick() {
    _b.addAll(escPosKickBytes);
    return this;
  }

  List<int> bytes() => List.unmodifiable(_b);
}

/// Two-column row: [left] flush-left, [right] flush-right, padded to [width].
/// If they'd collide, [right] wins and [left] is truncated.
String twoColumn(String left, String right, int width) {
  if (right.length >= width) return right.substring(0, width);
  final maxLeft = width - right.length - 1;
  final l = left.length > maxLeft ? left.substring(0, maxLeft) : left;
  final gap = width - l.length - right.length;
  return '$l${' ' * gap}$right';
}

String _fmtTimestamp(DateTime t) {
  final l = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${l.year}-${two(l.month)}-${two(l.day)} '
      '${two(l.hour)}:${two(l.minute)}';
}

/// Render a [ReceiptDocument] to ESC/POS bytes. [width] is the printer's
/// character columns (42 ≈ 80 mm, 32 ≈ 58 mm).
List<int> encodeReceipt(ReceiptDocument doc, {int width = 42}) {
  final e = EscPosEncoder()..init();
  final rule = '-' * width;

  e.align(EscAlign.center).bold(true).line(doc.storeName).bold(false);
  if (doc.storeSubtitle != null && doc.storeSubtitle!.isNotEmpty) {
    e.line(doc.storeSubtitle!);
  }
  e.align(EscAlign.left).line();
  e.line(_fmtTimestamp(doc.timestamp));
  e.line('Invoice: ${doc.invoiceNumber}');
  e.line(rule);

  for (final item in doc.items) {
    e.line(item.description);
    e.line(twoColumn('  ${item.quantity} x', item.lineTotal, width));
  }

  e.line(rule);
  e.line(twoColumn('Subtotal', doc.subtotal, width));
  e.line(twoColumn('Tax', doc.taxTotal, width));
  e.bold(true).line(twoColumn('TOTAL', doc.grandTotal, width)).bold(false);
  e.line(twoColumn('Tender', doc.tenderLabel, width));

  if (doc.footer != null && doc.footer!.isNotEmpty) {
    e.align(EscAlign.center).line().line(doc.footer!);
  }
  e.feed(3).cut();
  return e.bytes();
}

// --- Transports ------------------------------------------------------------
//
// A single byte sink both the printer and the drawer chain off. Real drawers
// are wired through the printer, so they share one transport.

abstract class EscPosTransport {
  Future<void> send(List<int> bytes);
}

/// Records writes — for tests and a dev "print preview".
class CapturingEscPosTransport implements EscPosTransport {
  final List<List<int>> writes = [];

  @override
  Future<void> send(List<int> bytes) async => writes.add(List.of(bytes));

  List<int> get lastWrite => writes.isEmpty ? const [] : writes.last;
}

/// TCP transport to a network ESC/POS printer (port 9100 by convention).
/// Assistant-built; USER validates against a real printer.
class NetworkEscPosTransport implements EscPosTransport {
  NetworkEscPosTransport(
    this.host,
    this.port, {
    this.timeout = const Duration(seconds: 5),
  });

  final String host;
  final int port;
  final Duration timeout;

  @override
  Future<void> send(List<int> bytes) async {
    final socket = await Socket.connect(host, port, timeout: timeout);
    try {
      socket.add(bytes);
      await socket.flush();
    } finally {
      await socket.close();
    }
  }
}

// --- ESC/POS-backed ports --------------------------------------------------

class EscPosReceiptPrinter implements ReceiptPrinter {
  EscPosReceiptPrinter(this.transport, {this.width = 42});

  final EscPosTransport transport;
  final int width;

  @override
  Future<void> printReceipt(ReceiptDocument doc) =>
      transport.send(encodeReceipt(doc, width: width));
}

class EscPosCashDrawer implements CashDrawer {
  EscPosCashDrawer(this.transport);

  final EscPosTransport transport;

  @override
  Future<void> kick() => transport.send(escPosKickBytes);
}

/// Spools the encoded ESC/POS receipt to a file (`file:PATH` target). An
/// OS-agnostic fallback: no printer needed — useful on the dev box to eyeball
/// output, or to `cat` the file to a printer later. Assistant-testable.
class FileReceiptPrinter implements ReceiptPrinter {
  FileReceiptPrinter(this.path, {this.width = 42});

  final String path;
  final int width;

  @override
  Future<void> printReceipt(ReceiptDocument doc) =>
      File(path).writeAsBytes(encodeReceipt(doc, width: width));
}
