import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// Shared stub adapter for notification tests. Returns 2 items (1 unread) for
/// an unfiltered list and 1 for ?status=unread.
class NotificationStub implements HttpClientAdapter {
  final List<String> calls = [];

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    final isUnreadQuery = options.queryParameters['status'] == 'unread';

    if (options.method == 'GET' && options.path == '/notifications/') {
      if (isUnreadQuery) {
        return _json({
          'count': 1,
          'results': [
            {'id': 1, 'title': 'Report approved', 'message': 'm', 'status': 'unread'}
          ],
        }, 200);
      }
      return _json({
        'count': 2,
        'results': [
          {'id': 1, 'title': 'Report approved', 'message': 'm', 'status': 'unread'},
          {'id': 2, 'title': 'Added to a project', 'message': 'm', 'status': 'read'},
        ],
      }, 200);
    }
    if (options.method == 'PATCH') {
      return _json({'id': 1, 'title': 'x', 'message': 'm', 'status': 'read'}, 200);
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}
