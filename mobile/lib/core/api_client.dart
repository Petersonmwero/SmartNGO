import 'package:dio/dio.dart';

import 'config.dart';
import 'token_storage.dart';

/// Paths under /auth/ that must NOT receive a bearer token or trigger a refresh.
const _publicPaths = <String>{
  '/auth/login/',
  '/auth/register/',
  '/auth/token/refresh/',
  '/auth/password-reset/',
  '/auth/password-reset/confirm/',
};

/// Called when the refresh token is no longer valid; the app should log out.
typedef OnAuthFailure = void Function();

/// Wraps a configured Dio instance:
///  - attaches the JWT access token to authenticated requests
///  - on 401, transparently refreshes the token once and retries
class ApiClient {
  final Dio dio;
  final TokenStore _store;
  final OnAuthFailure? onAuthFailure;

  // Guards against multiple concurrent refreshes.
  Future<String?>? _refreshing;

  ApiClient(this._store, {this.onAuthFailure, Dio? dio})
      : dio = dio ??
            Dio(BaseOptions(
              baseUrl: AppConfig.baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 15),
              contentType: Headers.jsonContentType,
            )) {
    this.dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: _onRequest,
            onError: _onError,
          ),
        );
  }

  bool _isPublic(String path) => _publicPaths.any(path.contains);

  Future<void> _onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (!_isPublic(options.path)) {
      final token = await _store.readAccess();
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
    }
    handler.next(options);
  }

  Future<void> _onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;
    final options = err.requestOptions;
    final alreadyRetried = options.extra['__retried__'] == true;

    final shouldRefresh = response?.statusCode == 401 &&
        !_isPublic(options.path) &&
        !alreadyRetried;

    if (!shouldRefresh) {
      return handler.next(err);
    }

    final newToken = await _refreshToken();
    if (newToken == null) {
      onAuthFailure?.call();
      return handler.next(err);
    }

    // Retry the original request once with the refreshed token.
    try {
      options.extra['__retried__'] = true;
      options.headers['Authorization'] = 'Bearer $newToken';
      final retried = await dio.fetch(options);
      return handler.resolve(retried);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Refresh the access token, coalescing concurrent callers. Returns the new
  /// access token, or null if refresh failed.
  Future<String?> _refreshToken() {
    return _refreshing ??= _doRefresh().whenComplete(() => _refreshing = null);
  }

  Future<String?> _doRefresh() async {
    final refresh = await _store.readRefresh();
    if (refresh == null) return null;
    try {
      // Safe to reuse `dio`: '/auth/token/refresh/' is a public path, so the
      // interceptor neither attaches a token nor recurses on a 401.
      final res =
          await dio.post('/auth/token/refresh/', data: {'refresh': refresh});
      final access = res.data['access'] as String?;
      final newRefresh = res.data['refresh'] as String?; // rotation enabled server-side
      if (access == null) return null;
      await _store.saveTokens(access: access, refresh: newRefresh ?? refresh);
      return access;
    } on DioException {
      await _store.clear();
      return null;
    }
  }
}
