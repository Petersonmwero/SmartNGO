import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/beneficiary.dart';

class BeneficiaryRepository {
  final ApiClient _api;

  BeneficiaryRepository(this._api);

  Future<Paginated<Beneficiary>> list({int? projectId, int page = 1}) {
    return apiGuard(() async {
      final query = <String, dynamic>{'page': page};
      if (projectId != null) query['project_id'] = projectId;
      final res = await _api.dio.get('/beneficiaries/', queryParameters: query);
      return Paginated.fromJson(
          res.data as Map<String, dynamic>, Beneficiary.fromJson);
    });
  }

  Future<int> count({int? projectId}) async {
    final page = await list(projectId: projectId);
    return page.count;
  }

  Future<Beneficiary> create({
    required int projectId,
    required String name,
    required String gender,
    String? dateOfBirth,
    String phone = '',
    String location = '',
  }) {
    return apiGuard(() async {
      final body = <String, dynamic>{
        'project': projectId,
        'name': name,
        'gender': gender,
        'phone': phone,
        'location': location,
      };
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      final res = await _api.dio.post('/beneficiaries/', data: body);
      return Beneficiary.fromJson(res.data as Map<String, dynamic>);
    });
  }

  /// Soft-delete (the server flips is_active to false).
  Future<void> delete(int id) {
    return apiGuard(() async {
      await _api.dio.delete('/beneficiaries/$id/');
    });
  }
}
