/// Wire DTOs for the cloud-api reports endpoints (slice 5.3).
///
/// JSON shapes mirror internal/reports/reports.go:
///   MoneyAmount      → {currency_code, units, nanos}
///   SalesSummaryBucket → {period_start, revenue, tax, grand_total}
///   SalesByMethodBucket → {period_start, method, amount}
///
/// Kept as plain immutable classes — json_serializable would be 6 lines
/// of generated code for 3 small types and adds a build_runner step the
/// app otherwise doesn't need.
library;

class MoneyAmount {
  final String currencyCode;
  final int units;
  final int nanos;

  const MoneyAmount({
    required this.currencyCode,
    required this.units,
    required this.nanos,
  });

  static const zero = MoneyAmount(currencyCode: '', units: 0, nanos: 0);

  factory MoneyAmount.fromJson(Map<String, dynamic> j) => MoneyAmount(
        currencyCode: j['currency_code'] as String? ?? '',
        units: (j['units'] as num?)?.toInt() ?? 0,
        nanos: (j['nanos'] as num?)?.toInt() ?? 0,
      );
}

class SalesSummaryBucket {
  final String periodStart;
  final MoneyAmount revenue;
  final MoneyAmount tax;
  final MoneyAmount grandTotal;

  const SalesSummaryBucket({
    required this.periodStart,
    required this.revenue,
    required this.tax,
    required this.grandTotal,
  });

  factory SalesSummaryBucket.fromJson(Map<String, dynamic> j) =>
      SalesSummaryBucket(
        periodStart: j['period_start'] as String,
        revenue:
            MoneyAmount.fromJson(j['revenue'] as Map<String, dynamic>),
        tax: MoneyAmount.fromJson(j['tax'] as Map<String, dynamic>),
        grandTotal: MoneyAmount.fromJson(
            j['grand_total'] as Map<String, dynamic>),
      );
}

class SalesByMethodBucket {
  final String periodStart;
  final String method; // "cash" | "card" | "upi" | "other"
  final MoneyAmount amount;

  const SalesByMethodBucket({
    required this.periodStart,
    required this.method,
    required this.amount,
  });

  factory SalesByMethodBucket.fromJson(Map<String, dynamic> j) =>
      SalesByMethodBucket(
        periodStart: j['period_start'] as String,
        method: j['method'] as String,
        amount: MoneyAmount.fromJson(j['amount'] as Map<String, dynamic>),
      );
}

/// Combined view-model the dashboard renders. Empty days collapse to a
/// row with revenue/tax/grandTotal == zero and methods == [].
class TodayDashboard {
  final String date; // ISO yyyy-MM-dd
  final MoneyAmount revenue;
  final MoneyAmount tax;
  final MoneyAmount grandTotal;
  final List<SalesByMethodBucket> methods;

  const TodayDashboard({
    required this.date,
    required this.revenue,
    required this.tax,
    required this.grandTotal,
    required this.methods,
  });

  bool get isEmpty =>
      revenue.units == 0 &&
      revenue.nanos == 0 &&
      tax.units == 0 &&
      tax.nanos == 0 &&
      methods.isEmpty;
}
