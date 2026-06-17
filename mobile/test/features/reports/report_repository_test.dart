import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/reports/report_repository.dart';

/// Records method+path and returns canned responses (handles multipart too).
class RecordingAdapter implements HttpClientAdapter {
  final List<String> calls = [];

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    if (options.path == '/reports/') return _json({'id': 99}, 201);
    return _json({}, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ReportRepository repo;
  late RecordingAdapter rec;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    rec = RecordingAdapter();
    dio.httpClientAdapter = rec;
    repo = ReportRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('createReport returns the new id', () async {
    final id = await repo.createReport(
      projectId: 3,
      title: 'Day 1',
      reportType: 'daily',
      latitude: 0.28,
      longitude: 35.11,
    );
    expect(id, 99);
    expect(rec.calls, contains('POST /reports/'));
  });

  test('uploadImage posts multipart to the nested URL', () async {
    await repo.uploadImage(
      99,
      bytes: Uint8List.fromList([1, 2, 3]),
      filename: 'photo.png',
      caption: 'site',
    );
    expect(rec.calls, contains('POST /reports/99/images/'));
  });

  test('submit posts to the submit action', () async {
    await repo.submit(99);
    expect(rec.calls, contains('POST /reports/99/submit/'));
  });
}
