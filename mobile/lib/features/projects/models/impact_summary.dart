/// Donor-facing roll-up of a project's **approved** field reports.
///
/// Mirrors `ProjectImpactSummarySerializer` on the backend. Unapproved work
/// is excluded server-side, so everything here is signed off.
class ImpactSummary {
  final int approvedReports;
  final int reached;
  final int male;
  final int female;
  final int youth;
  final int unspecified;
  final double reportedSpend;
  final double totalSpent;
  final double? costPerBeneficiary;
  final List<ActivityBreakdown> byActivity;

  const ImpactSummary({
    this.approvedReports = 0,
    this.reached = 0,
    this.male = 0,
    this.female = 0,
    this.youth = 0,
    this.unspecified = 0,
    this.reportedSpend = 0,
    this.totalSpent = 0,
    this.costPerBeneficiary,
    this.byActivity = const [],
  });

  static double _asDouble(dynamic value) {
    if (value == null) return 0;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString()) ?? 0;
  }

  factory ImpactSummary.fromJson(Map<String, dynamic> json) {
    final reach = (json['reach'] ?? const {}) as Map<String, dynamic>;
    return ImpactSummary(
      approvedReports: (json['approved_reports'] ?? 0) as int,
      reached: (reach['total'] ?? 0) as int,
      male: (reach['male'] ?? 0) as int,
      female: (reach['female'] ?? 0) as int,
      youth: (reach['youth'] ?? 0) as int,
      unspecified: (reach['unspecified'] ?? 0) as int,
      reportedSpend: _asDouble(json['reported_spend']),
      totalSpent: _asDouble(json['total_spent']),
      costPerBeneficiary: json['cost_per_beneficiary'] == null
          ? null
          : _asDouble(json['cost_per_beneficiary']),
      byActivity: ((json['by_activity'] ?? []) as List<dynamic>)
          .map((e) => ActivityBreakdown.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// True when no approved report has recorded anything yet, so the UI can
  /// show an explanation instead of a wall of zeros.
  bool get isEmpty => approvedReports == 0;
}

/// One activity type's share of the reporting.
class ActivityBreakdown {
  final String activityType;
  final String label;
  final int reports;
  final int reached;
  final double amountSpent;

  const ActivityBreakdown({
    required this.activityType,
    required this.label,
    required this.reports,
    required this.reached,
    required this.amountSpent,
  });

  factory ActivityBreakdown.fromJson(Map<String, dynamic> json) =>
      ActivityBreakdown(
        activityType: (json['activity_type'] ?? '') as String,
        label: (json['label'] ?? '') as String,
        reports: (json['reports'] ?? 0) as int,
        reached: (json['beneficiaries_reached'] ?? 0) as int,
        amountSpent: ImpactSummary._asDouble(json['amount_spent']),
      );
}
