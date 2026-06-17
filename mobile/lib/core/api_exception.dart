import 'package:dio/dio.dart';

/// Normalised API error mirroring the backend's `{error, code}` envelope.
class ApiException implements Exception {
  final String message;
  final String code;
  final int? statusCode;

  ApiException(this.message, {this.code = 'error', this.statusCode});

  /// Build an [ApiException] from a Dio failure, reading the backend envelope
  /// when present.
  factory ApiException.fromDio(DioException e) {
    final response = e.response;
    final data = response?.data;
    if (data is Map) {
      final msg = data['error'] ?? data['detail'] ?? 'Request failed.';
      final code = data['code'] ?? 'error';
      return ApiException(
        msg.toString(),
        code: code.toString(),
        statusCode: response?.statusCode,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        'Cannot reach the server. Check your connection.',
        code: 'network_error',
      );
    }
    return ApiException(
      e.message ?? 'Unexpected error.',
      code: 'error',
      statusCode: response?.statusCode,
    );
  }

  @override
  String toString() => message;
}

/// Runs an API call and converts any [DioException] into an [ApiException].
Future<T> apiGuard<T>(Future<T> Function() run) async {
  try {
    return await run();
  } on DioException catch (e) {
    throw ApiException.fromDio(e);
  }
}
