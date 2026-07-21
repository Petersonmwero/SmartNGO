import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/assignment.dart';
import 'models/impact_summary.dart';
import 'models/indicator.dart';
import 'models/milestone.dart';
import 'models/phase.dart';
import 'models/project.dart';

class ProjectRepository {
  final ApiClient _api;

  ProjectRepository(this._api);

  Future<Paginated<Project>> list({String? status, int page = 1}) {
    return apiGuard(() async {
      final query = <String, dynamic>{'page': page};
      if (status != null) query['status'] = status;
      final res = await _api.dio.get('/projects/', queryParameters: query);
      return Paginated.fromJson(
          res.data as Map<String, dynamic>, Project.fromJson);
    });
  }

  Future<Project> get(int id) {
    return apiGuard(() async {
      final res = await _api.dio.get('/projects/$id/');
      return Project.fromJson(res.data as Map<String, dynamic>);
    });
  }

  Future<List<Milestone>> milestones(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio
          .get('/milestones/', queryParameters: {'project_id': projectId});
      return Paginated.fromJson(
              res.data as Map<String, dynamic>, Milestone.fromJson)
          .results;
    });
  }

  Future<List<Indicator>> indicators(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio
          .get('/indicators/', queryParameters: {'project_id': projectId});
      return Paginated.fromJson(
              res.data as Map<String, dynamic>, Indicator.fromJson)
          .results;
    });
  }

  Future<Project> create({
    required String name,
    required String description,
    required double budget,
    required String startDate,
    required String endDate,
    String status = 'planning',
  }) {
    return apiGuard(() async {
      final res = await _api.dio.post('/projects/', data: {
        'project_name': name,
        'description': description,
        'budget': budget,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      });
      return Project.fromJson(res.data as Map<String, dynamic>);
    });
  }

  Future<List<ProjectAssignment>> assignments(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio.get('/projects/$projectId/assignments/');
      return Paginated.fromJson(
              res.data as Map<String, dynamic>, ProjectAssignment.fromJson)
          .results;
    });
  }

  Future<Project> update(
    int id, {
    required String name,
    required String description,
    required double budget,
    required String startDate,
    required String endDate,
    required String status,
  }) {
    return apiGuard(() async {
      final res = await _api.dio.put('/projects/$id/', data: {
        'project_name': name,
        'description': description,
        'budget': budget,
        'start_date': startDate,
        'end_date': endDate,
        'status': status,
      });
      return Project.fromJson(res.data as Map<String, dynamic>);
    });
  }

  /// Assign a user to the project team (role: manager | officer).
  Future<void> assign(int projectId, int userId, {String role = 'officer'}) {
    return apiGuard(() async {
      await _api.dio.post('/projects/$projectId/assignments/',
          data: {'user': userId, 'role': role});
    });
  }

  Future<void> removeAssignment(int projectId, int userId) {
    return apiGuard(() async {
      await _api.dio.delete('/projects/$projectId/assignments/$userId/');
    });
  }

  Future<void> createMilestone(
    int projectId, {
    required String title,
    required String dueDate,
    String description = '',
    int weight = 1,
  }) {
    return apiGuard(() async {
      await _api.dio.post('/milestones/', data: {
        'project': projectId,
        'title': title,
        'due_date': dueDate,
        'description': description,
        'weight': weight,
      });
    });
  }

  /// Donor-facing roll-up of the project's approved reports.
  Future<ImpactSummary> impactSummary(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio.get('/projects/$projectId/impact-summary/');
      final body = res.data as Map<String, dynamic>;
      // Newer endpoints wrap payloads in the {status, data} envelope.
      final data = (body['data'] ?? body) as Map<String, dynamic>;
      return ImpactSummary.fromJson(data);
    });
  }

  /// The impact roll-up as a PDF.
  ///
  /// Returns raw bytes rather than a URL: the endpoint needs the JWT the Dio
  /// interceptor attaches, so the browser cannot fetch it from a plain link.
  Future<Uint8List> impactReportPdf(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio.get<List<int>>(
        '/projects/$projectId/impact-report/',
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(res.data ?? const []);
    });
  }

  // ── Project phases (EVM budget breakdown) ───────────────────────────────
  Future<List<ProjectPhase>> phases(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio.get('/projects/$projectId/phases/');
      return Paginated.fromJson(
              res.data as Map<String, dynamic>, ProjectPhase.fromJson)
          .results;
    });
  }

  Future<void> createPhase(int projectId, Map<String, dynamic> data) {
    return apiGuard(() async {
      await _api.dio.post('/projects/$projectId/phases/', data: data);
    });
  }

  Future<void> updatePhase(
      int projectId, int phaseId, Map<String, dynamic> data) {
    return apiGuard(() async {
      await _api.dio
          .patch('/projects/$projectId/phases/$phaseId/', data: data);
    });
  }

  Future<void> deletePhase(int projectId, int phaseId) {
    return apiGuard(() async {
      await _api.dio.delete('/projects/$projectId/phases/$phaseId/');
    });
  }

  Future<void> createIndicator(
    int projectId, {
    required String name,
    required double targetValue,
    String unit = '',
  }) {
    return apiGuard(() async {
      await _api.dio.post('/indicators/', data: {
        'project': projectId,
        'indicator_name': name,
        'target_value': targetValue,
        'unit': unit,
      });
    });
  }
}
