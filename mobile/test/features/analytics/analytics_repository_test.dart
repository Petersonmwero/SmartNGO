import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/analytics/analytics_repository.dart';

/// Serves the wrapped analytics envelope and records what was asked for, so we
/// test URL construction, query params, envelope unwrapping and parsing.
class StubAdapter implements HttpClientAdapter {
  final List<String> requested = [];
  Map<String, dynamic> lastQuery = const {};

  ResponseBody _json(Map<String, dynamic> body) => ResponseBody.fromString(
        jsonEncode(body),
        200,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType]
        },
      );

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    requested.add(options.path);
    lastQuery = options.queryParameters;
    if (options.path == '/analytics/reports-series/') {
      return _json({
        'status': 'success',
        'message': 'ok',
        'data': {
          'months': 6,
          'series': [
            {
              'year': 2026,
              'month': 6,
              'label': 'Jun 2026',
              'submitted': 0,
              'approved': 0,
              'beneficiaries_reached': 0,
              'amount_spent': '0.00',
            },
            {
              'year': 2026,
              'month': 7,
              'label': 'Jul 2026',
              'submitted': 4,
              'approved': 2,
              'beneficiaries_reached': 130,
              // DRF renders DecimalField as a JSON string.
              'amount_spent': '125000.00',
            },
          ],
        },
      });
    }
    return _json({});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late AnalyticsRepository repo;
  late StubAdapter stub;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    stub = StubAdapter();
    dio.httpClientAdapter = stub;
    repo = AnalyticsRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('reportsSeries unwraps the envelope and parses points', () async {
    final series = await repo.reportsSeries();
    expect(stub.requested, contains('/analytics/reports-series/'));
    expect(series.months, 6);
    expect(series.series, hasLength(2));

    final july = series.series.last;
    expect(july.label, 'Jul 2026');
    expect(july.submitted, 4);
    expect(july.approved, 2);
    expect(july.beneficiariesReached, 130);
    // Decimal string parsed to a double.
    expect(july.amountSpent, closeTo(125000, 0.001));
  });

  test('reportsSeries passes the months window as a query param', () async {
    await repo.reportsSeries(months: 12);
    expect(stub.lastQuery['months'], 12);
    // No project filter → the key is omitted entirely.
    expect(stub.lastQuery.containsKey('project_id'), isFalse);
  });

  test('reportsSeries forwards an optional project filter', () async {
    await repo.reportsSeries(projectId: 42);
    expect(stub.lastQuery['project_id'], 42);
  });

  test('isEmpty is true only when nothing was submitted', () async {
    final withActivity = await repo.reportsSeries();
    expect(withActivity.isEmpty, isFalse); // July has 4 submitted

    // A window of all-zero months reads as empty.
    const allZero = ReportSeries(months: 2, series: [
      ReportSeriesPoint(
          year: 2026,
          month: 5,
          label: 'May 2026',
          submitted: 0,
          approved: 0,
          beneficiariesReached: 0,
          amountSpent: 0),
      ReportSeriesPoint(
          year: 2026,
          month: 6,
          label: 'Jun 2026',
          submitted: 0,
          approved: 0,
          beneficiariesReached: 0,
          amountSpent: 0),
    ]);
    expect(allZero.isEmpty, isTrue);
  });
}
