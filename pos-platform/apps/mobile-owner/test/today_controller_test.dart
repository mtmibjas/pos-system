import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/core/http_client.dart';
import 'package:mobile_owner/features/today/today_controller.dart';
import 'package:mobile_owner/features/today/today_repository.dart';

/// End-to-end-ish: override only the http.Client so the real repository
/// + provider wiring runs. Confirms the FutureProvider resolves to a
/// dashboard with the expected revenue.
void main() {
  test('FutureProvider returns dashboard from canned http responses',
      () async {
    final client = MockClient((req) async {
      Map<String, dynamic> body;
      if (req.url.path.endsWith('sales-summary')) {
        body = {
          'buckets': [
            {
              'period_start': '2026-05-31',
              'revenue': {
                'currency_code': 'USD',
                'units': 42,
                'nanos': 0
              },
              'tax': {'currency_code': 'USD', 'units': 4, 'nanos': 0},
              'grand_total': {
                'currency_code': 'USD',
                'units': 46,
                'nanos': 0
              },
            }
          ]
        };
      } else {
        body = {'buckets': []};
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    });

    final container = ProviderContainer(
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    final dash = await container.read(todayControllerProvider.future);
    expect(dash.revenue.units, 42);
    expect(dash.grandTotal.units, 46);
  });

  test('FutureProvider surfaces AuthException as error', () async {
    final client =
        MockClient((_) async => http.Response('nope', 401));
    final container = ProviderContainer(
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    await expectLater(
      container.read(todayControllerProvider.future),
      throwsA(isA<AuthException>()),
    );
  });
}
