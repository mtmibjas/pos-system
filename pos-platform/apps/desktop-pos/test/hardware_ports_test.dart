/// Hardware factory selection + scanner-port tests
/// (docs/desktop-hardware-ports.md §8).
library;

import 'package:desktop_pos/config.dart';
import 'package:desktop_pos/hardware/esc_pos.dart';
import 'package:desktop_pos/hardware/hardware_providers.dart';
import 'package:desktop_pos/hardware/noop_adapters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parsePrinterTarget', () {
    test('noop / empty / malformed → null', () {
      expect(parsePrinterTarget('noop'), isNull);
      expect(parsePrinterTarget(''), isNull);
      expect(parsePrinterTarget('network:host'), isNull);
      expect(parsePrinterTarget('network:host:'), isNull);
      expect(parsePrinterTarget('network:host:0'), isNull);
      expect(parsePrinterTarget('network:host:70000'), isNull);
    });
    test('valid network target parses host + port', () {
      final ep = parsePrinterTarget('network:192.168.1.50:9100');
      expect(ep, isNotNull);
      expect(ep!.host, '192.168.1.50');
      expect(ep.port, 9100);
    });
  });

  group('provider factory', () {
    test('defaults to Noop adapters (unconfigured terminal)', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(escPosTransportProvider), isNull);
      expect(c.read(receiptPrinterProvider), isA<NoopReceiptPrinter>());
      expect(c.read(cashDrawerProvider), isA<NoopCashDrawer>());
      expect(c.read(customerDisplayProvider), isA<NoopCustomerDisplay>());
      expect(c.read(barcodeScannerProvider), isA<WedgeBarcodeScanner>());
    });

    test('file target selects the FileReceiptPrinter (drawer stays Noop)', () {
      final c = ProviderContainer(overrides: [
        terminalConfigProvider.overrideWithValue(const TerminalConfig(
          serverUrl: 'http://127.0.0.1:8081',
          storeId: 'store-1',
          counterId: 'counter-1',
          terminalName: 'till',
          printerTarget: 'file:/tmp/receipt.escpos',
        )),
      ]);
      addTearDown(c.dispose);
      expect(c.read(receiptPrinterProvider), isA<FileReceiptPrinter>());
      expect(c.read(cashDrawerProvider), isA<NoopCashDrawer>());
    });

    test('network target selects ESC/POS adapters', () {
      final c = ProviderContainer(overrides: [
        terminalConfigProvider.overrideWithValue(const TerminalConfig(
          serverUrl: 'http://127.0.0.1:8081',
          storeId: 'store-1',
          counterId: 'counter-1',
          terminalName: 'till',
          printerTarget: 'network:1.2.3.4:9100',
        )),
      ]);
      addTearDown(c.dispose);
      expect(c.read(escPosTransportProvider), isA<NetworkEscPosTransport>());
      expect(c.read(receiptPrinterProvider), isA<EscPosReceiptPrinter>());
      expect(c.read(cashDrawerProvider), isA<EscPosCashDrawer>());
    });
  });

  group('BarcodeScanner adapters', () {
    test('WedgeBarcodeScanner emits a scan on terminate', () async {
      final s = WedgeBarcodeScanner();
      addTearDown(s.dispose);
      final scans = <String>[];
      s.scans.listen(scans.add);

      for (final ch in '4901234567894'.split('')) {
        s.feedChar(ch);
      }
      s.terminate();
      await Future<void>.delayed(Duration.zero);
      expect(scans, ['4901234567894']);
    });

    test('terminate with an empty buffer emits nothing', () async {
      final s = WedgeBarcodeScanner();
      addTearDown(s.dispose);
      final scans = <String>[];
      s.scans.listen(scans.add);
      s.terminate();
      await Future<void>.delayed(Duration.zero);
      expect(scans, isEmpty);
    });

    test('SimulatedScanner pushes scans directly', () async {
      final s = SimulatedScanner();
      addTearDown(s.dispose);
      final scans = <String>[];
      s.scans.listen(scans.add);
      s.emit('SKU-123');
      await Future<void>.delayed(Duration.zero);
      expect(scans, ['SKU-123']);
    });
  });
}
