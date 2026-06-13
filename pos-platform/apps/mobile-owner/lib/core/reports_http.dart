/// Low-level GET helper for reports endpoints. Centralises the 401/403
/// → AuthException mapping and JSON decoding so each repository stays
/// a thin wrapper of "build URL, call this, parse buckets".
library;

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'reports_errors.dart';

Future<Map<String, dynamic>> reportsGetJson(
    http.Client client, Uri uri) async {
  final resp = await client.get(uri, headers: {'Accept': 'application/json'});
  if (resp.statusCode == 200) {
    return jsonDecode(resp.body) as Map<String, dynamic>;
  }
  if (resp.statusCode == 401 || resp.statusCode == 403) {
    throw AuthException(resp.statusCode);
  }
  throw ReportException(resp.statusCode, resp.body);
}

/// Local-date ISO string (YYYY-MM-DD) — matches what cloud-api's
/// reports.ParseDateRange expects on `from=` / `to=`.
String isoDate(DateTime t) {
  final y = t.year.toString().padLeft(4, '0');
  final m = t.month.toString().padLeft(2, '0');
  final d = t.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
