/// HTTP repository for the today dashboard.
///
/// Talks JSON to cloud-api's /v1/reports/* endpoints. Two GETs in
/// parallel (sales-summary + sales-by-method) — both filter on
/// from=today, period=day. Returns a [TodayDashboard] view-model.
///
/// Error model lives in core/reports_errors.dart (re-exported here so
/// pre-existing imports from this file continue to compile).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../core/http_client.dart';
import '../../core/reports_http.dart';
import '../../core/server_url.dart';
import 'today_models.dart';

export '../../core/reports_errors.dart';

class TodayRepository {
  TodayRepository(this._client, {required Uri baseUrl, DateTime Function()? now})
      : _baseUrl = baseUrl,
        _now = now ?? DateTime.now;

  final http.Client _client;
  final Uri _baseUrl;
  final DateTime Function() _now;

  Future<TodayDashboard> fetchToday() async {
    final date = isoDate(_now());

    final summaryUri = _baseUrl.replace(
      path: '/v1/reports/sales-summary',
      queryParameters: {'from': date, 'period': 'day'},
    );
    final methodUri = _baseUrl.replace(
      path: '/v1/reports/sales-by-method',
      queryParameters: {'from': date},
    );

    // Parallel fetch — both routes are independent.
    final results = await Future.wait([
      reportsGetJson(_client, summaryUri),
      reportsGetJson(_client, methodUri),
    ]);
    final summaryJson = results[0];
    final methodJson = results[1];

    final summaryBuckets = (summaryJson['buckets'] as List? ?? const [])
        .map((b) => SalesSummaryBucket.fromJson(b as Map<String, dynamic>))
        .toList();
    final methodBuckets = (methodJson['buckets'] as List? ?? const [])
        .map((b) => SalesByMethodBucket.fromJson(b as Map<String, dynamic>))
        .toList();

    // Skip-empty contract: a day with no sales returns buckets=[]. We
    // collapse that to a zero-value dashboard rather than throwing, so
    // the UI shows "no sales yet today" cleanly.
    final summary = summaryBuckets.isEmpty
        ? SalesSummaryBucket(
            periodStart: date,
            revenue: MoneyAmount.zero,
            tax: MoneyAmount.zero,
            grandTotal: MoneyAmount.zero,
          )
        : summaryBuckets.first;

    return TodayDashboard(
      date: date,
      revenue: summary.revenue,
      tax: summary.tax,
      grandTotal: summary.grandTotal,
      methods: methodBuckets,
    );
  }
}

final todayRepositoryProvider = Provider<TodayRepository>((ref) {
  return TodayRepository(
    ref.watch(httpClientProvider),
    baseUrl: ref.watch(serverUrlProvider),
  );
});
