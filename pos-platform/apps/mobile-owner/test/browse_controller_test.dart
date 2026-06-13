import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:mobile_owner/core/http_client.dart';
import 'package:mobile_owner/features/browse/browse_controller.dart';
import 'package:mobile_owner/features/browse/browse_scope.dart';

void main() {
  test('controller re-fetches when scope changes', () async {
    var calls = 0;
    final captured = <String>[];
    final client = MockClient((req) async {
      calls++;
      captured.add(req.url.queryParameters['period'] ?? '');
      return http.Response(jsonEncode({'buckets': []}), 200);
    });

    final container = ProviderContainer(
      overrides: [httpClientProvider.overrideWithValue(client)],
    );
    addTearDown(container.dispose);

    // Initial scope = Day.
    await container.read(browseControllerProvider.future);
    expect(calls, 1);
    expect(captured.last, 'day');

    // Flip to Week → controller should refetch.
    container.read(browseScopeProvider.notifier).setPeriod(BrowsePeriod.week);
    await container.read(browseControllerProvider.future);
    expect(calls, 2);
    expect(captured.last, 'week');
  });
}
