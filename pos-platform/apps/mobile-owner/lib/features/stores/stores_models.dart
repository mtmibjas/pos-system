/// DTO for GET /v1/reports/stores (cloud-api slice 5.5).
library;

class StoreSummary {
  final String storeId;
  final String firstActivity; // YYYY-MM-DD
  final String lastActivity;  // YYYY-MM-DD

  const StoreSummary({
    required this.storeId,
    required this.firstActivity,
    required this.lastActivity,
  });

  factory StoreSummary.fromJson(Map<String, dynamic> j) => StoreSummary(
        storeId: j['store_id'] as String,
        firstActivity: j['first_activity'] as String? ?? '',
        lastActivity: j['last_activity'] as String? ?? '',
      );
}
