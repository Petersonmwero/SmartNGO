import 'package:dio/dio.dart';

import '../../core/api_client.dart';
import '../../core/api_exception.dart';
import '../../core/token_storage.dart';
import 'models/user.dart';

/// Handles authentication API calls and token/user persistence.
class AuthRepository {
  final ApiClient _api;
  final TokenStore _store;

  AuthRepository(this._api, this._store);

  Future<User> login(String email, String password) async {
    try {
      final res = await _api.dio.post('/auth/login/', data: {
        'email': email,
        'password': password,
      });
      final data = res.data as Map<String, dynamic>;
      await _store.saveTokens(
        access: data['access'] as String,
        refresh: data['refresh'] as String,
      );
      final user = User.fromJson(data['user'] as Map<String, dynamic>);
      await _store.saveUser(user.toJson());
      return user;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<User> register({
    required String fullName,
    required String email,
    required String password,
    required String role, // officer | donor
    required int ngoId,
    String phone = '',
  }) async {
    try {
      final res = await _api.dio.post('/auth/register/', data: {
        'full_name': fullName,
        'email': email,
        'password': password,
        'role': role,
        'ngo': ngoId,
        'phone': phone,
      });
      return User.fromJson(res.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await _api.dio.post('/auth/password-reset/', data: {'email': email});
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Best-effort logout: blacklist the refresh token, then clear local state.
  Future<void> logout() async {
    final refresh = await _store.readRefresh();
    if (refresh != null) {
      try {
        await _api.dio.post('/auth/logout/', data: {'refresh': refresh});
      } on DioException {
        // Ignore network/token errors on logout — we clear locally regardless.
      }
    }
    await _store.clear();
  }

  Future<User?> cachedUser() async {
    final json = await _store.readUser();
    return json == null ? null : User.fromJson(json);
  }

  Future<bool> hasSession() async => (await _store.readAccess()) != null;
}
