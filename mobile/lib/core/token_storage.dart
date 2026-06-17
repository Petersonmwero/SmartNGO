import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Abstraction over token + cached-user persistence so it can be swapped for an
/// in-memory implementation in tests (flutter_secure_storage needs a platform).
abstract class TokenStore {
  Future<void> saveTokens({required String access, required String refresh});
  Future<String?> readAccess();
  Future<String?> readRefresh();
  Future<void> saveUser(Map<String, dynamic> user);
  Future<Map<String, dynamic>?> readUser();
  Future<void> clear();
}

/// Production implementation backed by flutter_secure_storage.
class SecureTokenStore implements TokenStore {
  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kUser = 'auth_user';

  final FlutterSecureStorage _storage;

  SecureTokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
  }

  @override
  Future<String?> readAccess() => _storage.read(key: _kAccess);

  @override
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);

  @override
  Future<void> saveUser(Map<String, dynamic> user) =>
      _storage.write(key: _kUser, value: jsonEncode(user));

  @override
  Future<Map<String, dynamic>?> readUser() async {
    final raw = await _storage.read(key: _kUser);
    if (raw == null) return null;
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kUser);
  }
}

/// In-memory store for tests.
class InMemoryTokenStore implements TokenStore {
  String? _access;
  String? _refresh;
  Map<String, dynamic>? _user;

  @override
  Future<void> saveTokens({required String access, required String refresh}) async {
    _access = access;
    _refresh = refresh;
  }

  @override
  Future<String?> readAccess() async => _access;

  @override
  Future<String?> readRefresh() async => _refresh;

  @override
  Future<void> saveUser(Map<String, dynamic> user) async => _user = user;

  @override
  Future<Map<String, dynamic>?> readUser() async => _user;

  @override
  Future<void> clear() async {
    _access = null;
    _refresh = null;
    _user = null;
  }
}
