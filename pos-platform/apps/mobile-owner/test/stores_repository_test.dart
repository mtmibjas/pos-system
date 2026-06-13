import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/core/reports_errors.dart';
import 'package:mobile_owner/features/stores/stores_repository.dart';

StoresRepository _newRepo(http.Client c) =>
    StoresRepository(c, baseUrl: Uri.parse('http://example.test:8080'));

void main() {
  test('parses store list with first/last dates', () async {
    final body = {
      'stores': [
        {
          'store_id': 'store-A',
          'first_activity': '2026-05-01',
          'last_activity': '2026-05-31',
        },
        {
          'store_id': 'store-B',
          'first_activity': '2026-05-15',
          'last_activity': '2026-05-20',
        },
      ]
    };
    Uri? captured;
    final client = MockClient((req) async {
      captured = req.url;
      return http.Response(jsonEncode(body), 200);
    });
    final stores = await _newRepo(client).fetchStores();
    expect(captured!.path, '/v1/reports/stores');
    expect(stores.length, 2);
    expect(stores[0].storeId, 'store-A');
    expect(stores[0].firstActivity, '2026-05-01');
    expect(stores[1].lastActivity, '2026-05-20');
  });

  test('401 surfaces as AuthException', () async {
    final client = MockClient((_) async => http.Response('nope', 401));
    await expectLater(
      _newRepo(client).fetchStores(),
      throwsA(isA<AuthException>()),
    );
  });
}
