/// Byte-level tests for the ESC/POS encoder + receipt renderer + adapters
/// (docs/desktop-hardware-ports.md §8). No printer required.
library;

import 'dart:io';

import 'package:desktop_pos/hardware/esc_pos.dart';
import 'package:desktop_pos/hardware/receipt_document.dart';
import 'package:flutter_test/flutter_test.dart';

ReceiptDocument _sampleDoc() => ReceiptDocument(
      storeName: 'Corner Store',
      storeSubtitle: 'Colombo',
      invoiceNumber: 'INV-2026-000042',
      timestamp: DateTime.utc(2026, 8, 2, 10, 30),
      items: const [
        ReceiptLineItem(description: 'Rice 1kg', quantity: 3, lineTotal: '1,725.00'),
        ReceiptLineItem(description: 'Tea 100g', quantity: 1, lineTotal: '450.00'),
      ],
      subtotal: 'LKR 2175.00',
      taxTotal: 'LKR 0.00',
      grandTotal: 'LKR 2175.00',
      tenderLabel: 'CASH  LKR 2175.00',
      footer: 'Thank you!',
    );

void main() {
  group('EscPosEncoder', () {
    test('control sequences', () {
      expect(EscPosEncoder().init().bytes(), [0x1B, 0x40]);
      expect(EscPosEncoder().align(EscAlign.center).bytes(), [0x1B, 0x61, 1]);
      expect(EscPosEncoder().align(EscAlign.right).bytes(), [0x1B, 0x61, 2]);
      expect(EscPosEncoder().bold(true).bytes(), [0x1B, 0x45, 1]);
      expect(EscPosEncoder().bold(false).bytes(), [0x1B, 0x45, 0]);
      expect(EscPosEncoder().feed(2).bytes(), [0x1B, 0x64, 2]);
      expect(EscPosEncoder().cut().bytes(), [0x1D, 0x56, 0x00]);
      expect(EscPosEncoder().kick().bytes(), escPosKickBytes);
    });

    test('text encodes ascii and maps non-latin1 to ?', () {
      expect(EscPosEncoder().text('AB').bytes(), [65, 66]);
      expect(EscPosEncoder().line('A').bytes(), [65, 0x0A]);
      // '√' (U+221A) is > 0xFF → '?'.
      expect(EscPosEncoder().text('A√B').bytes(), [65, 0x3F, 66]);
    });
  });

  group('twoColumn', () {
    test('pads left/right to width', () {
      expect(twoColumn('Subtotal', '100.00', 20), 'Subtotal      100.00');
      expect(twoColumn('Subtotal', '100.00', 20), hasLength(20));
    });
    test('right value wins when it fills the width', () {
      expect(twoColumn('very-long-left', '123456', 6), '123456');
    });
  });

  group('encodeReceipt', () {
    test('starts with init and ends with cut', () {
      final b = encodeReceipt(_sampleDoc());
      expect(b.sublist(0, 2), [0x1B, 0x40]);
      expect(b.sublist(b.length - 3), [0x1D, 0x56, 0x00]);
    });

    test('contains the store, invoice, items and totals', () {
      final text = String.fromCharCodes(encodeReceipt(_sampleDoc()));
      expect(text, contains('Corner Store'));
      expect(text, contains('Colombo'));
      expect(text, contains('INV-2026-000042'));
      expect(text, contains('Rice 1kg'));
      expect(text, contains('TOTAL'));
      expect(text, contains('LKR 2175.00'));
      expect(text, contains('Thank you!'));
    });
  });

  group('ESC/POS adapters over a capturing transport', () {
    test('printer sends the encoded receipt', () async {
      final t = CapturingEscPosTransport();
      await EscPosReceiptPrinter(t).printReceipt(_sampleDoc());
      expect(t.writes, hasLength(1));
      expect(t.lastWrite, encodeReceipt(_sampleDoc()));
    });

    test('drawer sends the kick pulse', () async {
      final t = CapturingEscPosTransport();
      await EscPosCashDrawer(t).kick();
      expect(t.lastWrite, escPosKickBytes);
    });
  });

  test('FileReceiptPrinter spools the encoded receipt to disk', () async {
    final dir = await Directory.systemTemp.createTemp('escpos_test');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}/receipt.escpos';

    await FileReceiptPrinter(path).printReceipt(_sampleDoc());

    final bytes = await File(path).readAsBytes();
    expect(bytes, encodeReceipt(_sampleDoc()));
  });
}
