import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';

class Ngo {
  final int id;
  final String name;
  final String registrationNo;
  final String description;
  final String address;
  final String contact;
  final String createdAt;

  const Ngo({
    required this.id,
    required this.name,
    required this.registrationNo,
    required this.description,
    required this.address,
    required this.contact,
    required this.createdAt,
  });

  factory Ngo.fromJson(Map<String, dynamic> json) => Ngo(
        id: json['id'] as int,
        name: (json['name'] ?? '') as String,
        registrationNo: (json['registration_no'] ?? '') as String,
        description: (json['description'] ?? '') as String,
        address: (json['address'] ?? '') as String,
        contact: (json['contact'] ?? '') as String,
        createdAt: (json['created_at'] ?? '') as String,
      );
}

class NgoRepository {
  final ApiClient _api;
  NgoRepository(this._api);

  Future<Paginated<Ngo>> list({int page = 1}) {
    return apiGuard(() async {
      final res = await _api.dio.get('/ngos/', queryParameters: {'page': page});
      return Paginated.fromJson(res.data as Map<String, dynamic>, Ngo.fromJson);
    });
  }
}
