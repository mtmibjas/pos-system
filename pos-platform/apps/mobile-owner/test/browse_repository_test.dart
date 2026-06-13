import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/features/browse/browse_repository.dart';
import 'package:mobile_owner/features/browse/browse_scope.dart';

BrowseRepository _newRepo(http.Client c) =>
    BrowseRepository(c, baseUrl: Uri.parse('http://example.test:8080'));

http.Response _ok(Map<String, dynamic> body) =>
    http.Response(jsonEncode(body), 200);

void main() {
  test('week scope builds from/to/period query string', () async {
    Uri? captured;
    final client = MockClient((req) async {
      captured = req.url;
      return _ok({'buckets': []});
    });
    final scope = BrowseScope(
      period: BrowsePeriod.week,
      anchor: DateTime(2026, 5, 25), // Monday
      storeId: '',
    );

    await _newRepo(client).fetchSummary(scope);
    expect(captured, isNotNull);
    expect(captured!.path, '/v1/reports/sales-summary');
    expect(captured!.queryParameters['from'], '2026-05-25');
    expect(captured!.queryParameters['to'], '2026-06-01');
    expect(captured!.queryParameters['period'], 'week');
    expect(captured!.queryParameters.containsKey('store_id'), isFalse);
  });

  test('store filter is forwarded only when non-empty', () async {
    Uri? captured;
    final client = MockClient((req) async {
      captured = req.url;
      return _ok({'buckets': []});
    });
    final scope = BrowseScope(
      period: BrowsePeriod.day,
      anchor: DateTime(2026, 5, 31),
      storeId: 'store-A',
    );
    await _newRepo(client).fetchSummary(scope);
    expect(captured!.queryParameters['store_id'], 'store-A');
  });

  test('parses bucket list', () async {
    final body = {
      'buckets': [
        {
          'period_start': '2026-05-25',
          'revenue': {'currency_code': 'USD', 'units': 100, 'nanos': 0},
          'tax': {'currency_code': 'USD', 'units': 10, 'nanos': 0},
          'grand_total': {'currency_code': 'USD', 'units': 110, 'nanos': 0},
        },
        {
          'period_start': '2026-05-26',
          'revenue': {'currency_code': 'USD', 'units': 50, 'nanos': 0},
          'tax': {'currency_code': 'USD', 'units': 5, 'nanos': 0},
          'grand_total': {'currency_code': 'USD', 'units': 55, 'nanos': 0},
        },
      ]
    };
    final client = MockClient((_) async => _ok(body));
    final scope = BrowseScope(
      period: BrowsePeriod.week,
      anchor: DateTime(2026, 5, 25),
      storeId: '',
    );
    final buckets = await _newRepo(client).fetchSummary(scope);
    expect(buckets.length, 2);
    expect(buckets[0].periodStart, '2026-05-25');
    expect(buckets[1].grandTotal.units, 55);
  });
}
