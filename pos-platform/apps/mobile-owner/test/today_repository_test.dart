import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/features/today/today_models.dart';
import 'package:mobile_owner/features/today/today_repository.dart';

// Fixed clock so the date in the URL is deterministic.
DateTime _fixedNow() => DateTime(2026, 5, 31, 14, 0, 0);

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json'});

TodayRepository _newRepo(http.Client client) {
  return TodayRepository(
    client,
    baseUrl: Uri.parse('http://example.test:8080'),
    now: _fixedNow,
  );
}

void main() {
  test('happy path parses both endpoints and merges', () async {
    final summaryBody = {
      'buckets': [
        {
          'period_start': '2026-05-31',
          'revenue': {'currency_code': 'USD', 'units': 100, 'nanos': 0},
          'tax': {'currency_code': 'USD', 'units': 10, 'nanos': 0},
          'grand_total': {'currency_code': 'USD', 'units': 110, 'nanos': 0},
        }
      ]
    };
    final methodBody = {
      'buckets': [
        {
          'period_start': '2026-05-31',
          'method': 'cash',
          'amount': {'currency_code': 'USD', 'units': 80, 'nanos': 0},
        },
        {
          'period_start': '2026-05-31',
          'method': 'card',
          'amount': {'currency_code': 'USD', 'units': 30, 'nanos': 0},
        }
      ]
    };

    final captured = <Uri>[];
    final client = MockClient((req) async {
      captured.add(req.url);
      if (req.url.path == '/v1/reports/sales-summary') return _ok(summaryBody);
      if (req.url.path == '/v1/reports/sales-by-method') return _ok(methodBody);
      fail('unexpected URL: ${req.url}');
    });

    final dash = await _newRepo(client).fetchToday();

    expect(dash.date, '2026-05-31');
    expect(dash.revenue.units, 100);
    expect(dash.tax.units, 10);
    expect(dash.grandTotal.units, 110);
    expect(dash.methods.length, 2);
    expect(dash.methods.first.method, 'cash');

    // Both endpoints called with from=today.
    expect(captured.length, 2);
    for (final u in captured) {
      expect(u.queryParameters['from'], '2026-05-31');
    }
    expect(
      captured.firstWhere((u) => u.path.endsWith('sales-summary'))
          .queryParameters['period'],
      'day',
    );
  });

  test('empty buckets collapse to zero dashboard, not error', () async {
    final client = MockClient((_) async => _ok({'buckets': []}));
    final dash = await _newRepo(client).fetchToday();

    expect(dash.isEmpty, isTrue);
    expect(dash.revenue.units, 0);
    expect(dash.tax.units, 0);
    expect(dash.methods, isEmpty);
  });

  test('401 maps to AuthException', () async {
    final client =
        MockClient((_) async => http.Response('missing token', 401));
    await expectLater(
      _newRepo(client).fetchToday(),
      throwsA(isA<AuthException>()),
    );
  });

  test('403 maps to AuthException', () async {
    final client = MockClient((_) async => http.Response('not owner', 403));
    await expectLater(
      _newRepo(client).fetchToday(),
      throwsA(isA<AuthException>()),
    );
  });

  test('500 maps to ReportException', () async {
    final client = MockClient((_) async => http.Response('oops', 500));
    await expectLater(
      _newRepo(client).fetchToday(),
      throwsA(isA<ReportException>()),
    );
  });

  test('MoneyAmount.fromJson tolerates missing fields', () {
    final m = MoneyAmount.fromJson({});
    expect(m.currencyCode, '');
    expect(m.units, 0);
    expect(m.nanos, 0);
  });
}
