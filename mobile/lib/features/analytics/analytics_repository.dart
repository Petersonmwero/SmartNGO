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
}
