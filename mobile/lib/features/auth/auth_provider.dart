import 'package:flutter/foundation.dart';

import '../../core/api_exception.dart';
import 'auth_repository.dart';
import 'models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// App-wide authentication state.
class AuthProvider extends ChangeNotifier {
  final AuthRepository _repo;

  AuthProvider(this._repo);

  AuthStatus status = AuthStatus.unknown;
  User? user;
  bool busy = false;
  String? error;

  bool get isAuthenticated => status == AuthStatus.authenticated;

  /// Restore session from secure storage on app start, then refresh profile from server.
  Future<void> bootstrap() async {
    if (await _repo.hasSession()) {
      user = await _repo.cachedUser();
      status = AuthStatus.authenticated;
      notifyListeners();
      // Refresh profile in background so role/name changes propagate without re-login.
      try {
        user = await _repo.me();
        notifyListeners();
      } on ApiException {
        // Ignore — stale cache is acceptable if the server is unreachable.
      }
    } else {
      status = AuthStatus.unauthenticated;
      notifyListeners();
    }
  }

  Future<bool> login(String email, String password) async {
    _setBusy(true);
    try {
      user = await _repo.login(email, password);
      status = AuthStatus.authenticated;
      error = null;
      return true;
    } on ApiException catch (e) {
      error = e.message;
      return false;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    await _repo.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    error = null;
    notifyListeners();
  }

  /// Called by the API client when a refresh fails.
  void onSessionExpired() {
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  void _setBusy(bool value) {
    busy = value;
    notifyListeners();
  }
}
