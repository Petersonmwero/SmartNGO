import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/assignment.dart';
import 'models/indicator.dart';
import 'models/milestone.dart';
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

  Future<List<ProjectAssignment>> assignments(int projectId) {
    return apiGuard(() async {
      final res = await _api.dio.get('/projects/$projectId/assignments/');
      return Paginated.fromJson(
              res.data as Map<String, dynamic>, ProjectAssignment.fromJson)
          .results;
    });
  }
}
