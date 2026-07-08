import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/paginated.dart';

class ManagedUser {
  final int id;
  final String fullName;
  final String email;
  final String role;
  final String phone;
  final bool isActive;
  final String createdAt;

  const ManagedUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.phone,
    required this.isActive,
    required this.createdAt,
  });

  factory ManagedUser.fromJson(Map<String, dynamic> json) => ManagedUser(
        id: json['id'] as int,
        fullName: (json['full_name'] ?? '') as String,
        email: (json['email'] ?? '') as String,
        role: (json['role'] ?? '') as String,
        phone: (json['phone'] ?? '') as String,
        isActive: (json['is_active'] ?? true) as bool,
        createdAt: (json['created_at'] ?? '') as String,
      );

  String get roleLabel {
    switch (role) {
      case 'admin': return 'Administrator';
      case 'manager': return 'Project Manager';
      case 'officer': return 'Field Officer';
      case 'donor': return 'Donor';
      default: return role;
    }
  }
}

class UserRepository {
  final ApiClient _api;
  UserRepository(this._api);

  Future<Paginated<ManagedUser>> list({int page = 1}) {
    return apiGuard(() async {
      final res = await _api.dio.get('/users/', queryParameters: {'page': page});
      return Paginated.fromJson(
          res.data as Map<String, dynamic>, ManagedUser.fromJson);
    });
  }

  Future<void> toggleActive(int userId) {
    return apiGuard(() async {
      await _api.dio.patch('/users/$userId/toggle-active/');
    });
  }
}
