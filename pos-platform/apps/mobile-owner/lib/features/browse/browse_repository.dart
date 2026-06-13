/// Repository for the browse screen — fetches sales-summary buckets
/// over an arbitrary [from, to) range, period and optional store filter.
///
/// Returns the raw bucket list (not collapsed to a single dashboard
/// like today_repository does) because browse needs to render multiple
/// buckets in a list.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/http_client.dart';
import '../../core/reports_http.dart';
import '../../core/server_url.dart';
import '../today/today_models.dart';
import 'browse_scope.dart';

class BrowseRepository {
  BrowseRepository(this._client, {required Uri baseUrl}) : _baseUrl = baseUrl;

  final http.Client _client;
  final Uri _baseUrl;

  Future<List<SalesSummaryBucket>> fetchSummary(BrowseScope scope) async {
    final w = scope.window;
    final params = {
      'from': isoDate(w.from),
      'to': isoDate(w.to),
      'period': scope.period.wire,
    };
    if (scope.storeId.isNotEmpty) {
      params['store_id'] = scope.storeId;
    }
    final uri = _baseUrl.replace(
      path: '/v1/reports/sales-summary',
      queryParameters: params,
    );
    final body = await reportsGetJson(_client, uri);
    return ((body['buckets'] as List?) ?? const [])
        .map((b) => SalesSummaryBucket.fromJson(b as Map<String, dynamic>))
        .toList();
  }
}

final browseRepositoryProvider = Provider<BrowseRepository>((ref) {
  return BrowseRepository(
    ref.watch(httpClientProvider),
    baseUrl: ref.watch(serverUrlProvider),
  );
});
