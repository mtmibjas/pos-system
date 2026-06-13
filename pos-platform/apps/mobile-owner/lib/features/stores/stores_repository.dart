/// Stores list repository — drives the browse screen's store picker.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/http_client.dart';
import '../../core/reports_http.dart';
import '../../core/server_url.dart';
import 'stores_models.dart';

class StoresRepository {
  StoresRepository(this._client, {required Uri baseUrl}) : _baseUrl = baseUrl;

  final http.Client _client;
  final Uri _baseUrl;

  Future<List<StoreSummary>> fetchStores() async {
    final uri = _baseUrl.replace(path: '/v1/reports/stores');
    final body = await reportsGetJson(_client, uri);
    return ((body['stores'] as List?) ?? const [])
        .map((s) => StoreSummary.fromJson(s as Map<String, dynamic>))
        .toList();
  }
}

final storesRepositoryProvider = Provider<StoresRepository>((ref) {
  return StoresRepository(
    ref.watch(httpClientProvider),
    baseUrl: ref.watch(serverUrlProvider),
  );
});
