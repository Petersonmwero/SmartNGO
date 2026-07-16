import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';
import 'models/beneficiary.dart';

class BeneficiaryRepository {
  final ApiClient _api;

  BeneficiaryRepository(this._api);

  Future<Paginated<Beneficiary>> list(
      {int? projectId, String? gender, int page = 1}) {
    return apiGuard(() async {
      final query = <String, dynamic>{'page': page};
      if (projectId != null) query['project_id'] = projectId;
      if (gender != null) query['gender'] = gender;
      final res = await _api.dio.get('/beneficiaries/', queryParameters: query);
      return Paginated.fromJson(
          res.data as Map<String, dynamic>, Beneficiary.fromJson);
    });
  }

  Future<int> count({int? projectId, String? gender}) async {
    final page = await list(projectId: projectId, gender: gender);
    return page.count;
  }

  Future<Beneficiary> create({
    required int projectId,
    required String name,
    required String gender,
    String? dateOfBirth,
    String phone = '',
    String country = 'Kenya',
    String county = '',
    String constituency = '',
    String ward = '',
    String village = '',
  }) {
    return apiGuard(() async {
      final body = <String, dynamic>{
        'project': projectId,
        'name': name,
        'gender': gender,
        'phone': phone,
        'country': country,
        'county': county,
        'constituency': constituency,
        'ward': ward,
        'village': village,
      };
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      final res = await _api.dio.post('/beneficiaries/', data: body);
      return Beneficiary.fromJson(res.data as Map<String, dynamic>);
    });
  }

  // ── Kenya administrative reference data (cascading picker) ────────────

  Future<List<String>> kenyaCounties() =>
      _kenyaLocations({'counties': 'true'});

  Future<List<String>> kenyaConstituencies(String county) =>
      _kenyaLocations({'county': county});

  Future<List<String>> kenyaWards(String constituency) =>
      _kenyaLocations({'constituency': constituency});

  Future<List<String>> _kenyaLocations(Map<String, dynamic> query) {
    return apiGuard(() async {
      final res =
          await _api.dio.get('/locations/kenya/', queryParameters: query);
      final data = (res.data as Map<String, dynamic>)['data'];
      return (data as List<dynamic>).cast<String>();
    });
  }

  /// Soft-delete (the server flips is_active to false).
  Future<void> delete(int id) {
    return apiGuard(() async {
      await _api.dio.delete('/beneficiaries/$id/');
    });
  }
}
