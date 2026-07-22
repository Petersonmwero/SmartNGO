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

  /// Decoded JSON body of the last request that sent one (not multipart).
  Map<String, dynamic>? lastJsonBody;

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
    final contentType = options.contentType ?? '';
    if (requestStream != null && contentType.contains('json')) {
      final chunks = await requestStream.toList();
      lastJsonBody = jsonDecode(
        utf8.decode(chunks.expand((c) => c).toList()),
      ) as Map<String, dynamic>;
    }
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

  test('updateReport PATCHes and sends explicit clears', () async {
    await repo.updateReport(
      42,
      title: 'Revised',
      reportType: 'weekly',
      // Left blank on purpose: an edit should clear these, not omit them.
      amountSpent: '',
      linkedPhaseId: null,
      beneficiariesReached: 0,
    );
    expect(rec.calls, contains('PATCH /reports/42/'));
    // Blank amount clears to '0'; a null link is sent so it is unset.
    expect(rec.lastJsonBody!['amount_spent'], '0');
    expect(rec.lastJsonBody!.containsKey('linked_phase'), isTrue);
    expect(rec.lastJsonBody!['linked_phase'], isNull);
    expect(rec.lastJsonBody!['title'], 'Revised');
  });
}
