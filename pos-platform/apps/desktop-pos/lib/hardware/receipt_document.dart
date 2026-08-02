/// Structured receipt — the device-agnostic document controllers build
/// (docs/desktop-hardware-ports.md §4).
///
/// Adapters *render* this: ESC/POS → bytes, OS-fallback → HTML/PDF. Money is
/// carried pre-formatted (the domain owns `money_format.dart`) so the encoder
/// stays dumb and the P7 LK-invoice layout is a document concern, testable
/// without a printer.
library;

import 'package:flutter/foundation.dart' show immutable, listEquals;

@immutable
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.description,
    required this.quantity,
    required this.lineTotal,
  });

  final String description;
  final int quantity;
  final String lineTotal; // pre-formatted, e.g. "1,725.00"

  @override
  bool operator ==(Object other) =>
      other is ReceiptLineItem &&
      other.description == description &&
      other.quantity == quantity &&
      other.lineTotal == lineTotal;

  @override
  int get hashCode => Object.hash(description, quantity, lineTotal);
}

@immutable
class ReceiptDocument {
  const ReceiptDocument({
    required this.storeName,
    required this.invoiceNumber,
    required this.timestamp,
    required this.items,
    required this.subtotal,
    required this.taxTotal,
    required this.grandTotal,
    required this.tenderLabel,
    this.storeSubtitle,
    this.footer,
  });

  final String storeName;
  final String? storeSubtitle; // address / phone / VAT no. later
  final String invoiceNumber;
  final DateTime timestamp;
  final List<ReceiptLineItem> items;
  final String subtotal;
  final String taxTotal;
  final String grandTotal;
  final String tenderLabel; // e.g. "CASH  1,725.00"
  final String? footer;

  @override
  bool operator ==(Object other) =>
      other is ReceiptDocument &&
      other.storeName == storeName &&
      other.storeSubtitle == storeSubtitle &&
      other.invoiceNumber == invoiceNumber &&
      other.timestamp == timestamp &&
      listEquals(other.items, items) &&
      other.subtotal == subtotal &&
      other.taxTotal == taxTotal &&
      other.grandTotal == grandTotal &&
      other.tenderLabel == tenderLabel &&
      other.footer == footer;

  @override
  int get hashCode => Object.hash(storeName, invoiceNumber, timestamp,
      Object.hashAll(items), subtotal, taxTotal, grandTotal, tenderLabel);
}
