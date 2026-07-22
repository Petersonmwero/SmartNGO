import '../../core/api_client.dart';
import '../../core/api_exception.dart';

class ProjectStats {
  final int total;
  final Map<String, int> byStatus;
  const ProjectStats({required this.total, required this.byStatus});
  factory ProjectStats.fromJson(Map<String, dynamic> json) => ProjectStats(
        total: json['total'] as int,
        byStatus: Map<String, int>.from(json['by_status'] as Map),
      );
}

class ReportStats {
  final int draft;
  final int submitted;
  final int approved;
  const ReportStats({required this.draft, required this.submitted, required this.approved});
  factory ReportStats.fromJson(Map<String, dynamic> json) => ReportStats(
        draft: json['draft'] as int,
        submitted: json['submitted'] as int,
        approved: json['approved'] as int,
      );
}

class DashboardStats {
  final ProjectStats projects;
  final int beneficiaries;
  final ReportStats reports;
  final int unreadNotifications;

  const DashboardStats({
    required this.projects,
    required this.beneficiaries,
    required this.reports,
    required this.unreadNotifications,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) => DashboardStats(
        projects: ProjectStats.fromJson(json['projects'] as Map<String, dynamic>),
        beneficiaries: (json['beneficiaries'] as Map<String, dynamic>)['total'] as int,
        reports: ReportStats.fromJson(json['reports'] as Map<String, dynamic>),
        unreadNotifications:
            (json['notifications'] as Map<String, dynamic>)['unread'] as int,
      );
}

/// One month in the reporting trend series. `submitted` is every report whose
/// submission date falls in the month; `approved` is the subset since approved,
/// and reach/spend come only from those approved reports — matching the
/// server's donor-facing figures.
class ReportSeriesPoint {
  final int year;
  final int month;
  final String label; // e.g. "Jul 2026" — precomputed server-side.
  final int submitted;
  final int approved;
  final int beneficiariesReached;
  final double amountSpent;

  const ReportSeriesPoint({
    required this.year,
    required this.month,
    required this.label,
    required this.submitted,
    required this.approved,
    required this.beneficiariesReached,
    required this.amountSpent,
  });

  factory ReportSeriesPoint.fromJson(Map<String, dynamic> json) =>
      ReportSeriesPoint(
        year: json['year'] as int,
        month: json['month'] as int,
        label: json['label'] as String,
        submitted: json['submitted'] as int,
        approved: json['approved'] as int,
        beneficiariesReached: json['beneficiaries_reached'] as int,
        // DRF serialises DecimalField as a JSON string.
        amountSpent: double.tryParse(json['amount_spent'].toString()) ?? 0,
      );
}

/// A contiguous run of months, oldest first, zero-filled by the server so the
/// chart never has to patch gaps.
class ReportSeries {
  final int months;
  final List<ReportSeriesPoint> series;
  const ReportSeries({required this.months, required this.series});

  factory ReportSeries.fromJson(Map<String, dynamic> json) => ReportSeries(
        months: json['months'] as int,
        series: (json['series'] as List)
            .map((e) => ReportSeriesPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// True when nothing was submitted across the whole window.
  bool get isEmpty => series.every((p) => p.submitted == 0);
}

class AnalyticsRepository {
  final ApiClient _api;
  AnalyticsRepository(this._api);

  Future<DashboardStats> dashboard() {
    return apiGuard(() async {
      final res = await _api.dio.get('/analytics/dashboard/');
      // Response is wrapped: {status, data, message}
      final data = (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return DashboardStats.fromJson(data);
    });
  }

  /// Monthly reporting activity for the trend chart. Scoping matches the
  /// dashboard: the caller sees only reports they are allowed to see.
  Future<ReportSeries> reportsSeries({int months = 6, int? projectId}) {
    return apiGuard(() async {
      final res = await _api.dio.get(
        '/analytics/reports-series/',
        queryParameters: {
          'months': months,
          'project_id': ?projectId,
        },
      );
      final data =
          (res.data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
      return ReportSeries.fromJson(data);
    });
  }
}
