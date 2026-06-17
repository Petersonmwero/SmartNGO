import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/projects/project_repository.dart';

/// Returns canned JSON per path so we test parsing + URL construction.
class StubAdapter implements HttpClientAdapter {
  final List<String> requested = [];

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
    final p = options.path;
    if (p == '/projects/') {
      return _json({
        'count': 2,
        'next': null,
        'previous': null,
        'results': [
          {'id': 1, 'project_name': 'Water', 'budget': '100', 'status': 'active', 'ngo': 1},
          {'id': 2, 'project_name': 'Health', 'budget': '200', 'status': 'planning', 'ngo': 1},
        ],
      });
    }
    if (p == '/projects/1/') {
      return _json({'id': 1, 'project_name': 'Water', 'budget': '100', 'status': 'active', 'ngo': 1});
    }
    if (p == '/milestones/') {
      return _json({'count': 1, 'results': [
        {'id': 5, 'project': 1, 'title': 'Baseline', 'status': 'pending'}
      ]});
    }
    if (p == '/indicators/') {
      return _json({'count': 1, 'results': [
        {'id': 7, 'project': 1, 'indicator_name': 'Wells', 'target_value': '50', 'current_value': '10', 'unit': 'wells', 'progress_percent': 20.0}
      ]});
    }
    if (p == '/projects/1/assignments/') {
      return _json({'count': 1, 'results': [
        {'id': 3, 'project': 1, 'user': 9, 'user_name': 'Jane', 'role': 'officer'}
      ]});
    }
    return _json({});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late ProjectRepository repo;
  late StubAdapter stub;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    stub = StubAdapter();
    dio.httpClientAdapter = stub;
    repo = ProjectRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('list parses paginated projects', () async {
    final page = await repo.list();
    expect(page.count, 2);
    expect(page.results.first.projectName, 'Water');
    expect(page.results.first.statusLabel, 'Active');
  });

  test('get parses a single project', () async {
    final p = await repo.get(1);
    expect(p.id, 1);
    expect(p.projectName, 'Water');
  });

  test('milestones parses results list', () async {
    final items = await repo.milestones(1);
    expect(items, hasLength(1));
    expect(items.first.title, 'Baseline');
  });

  test('indicators parses results with progress', () async {
    final items = await repo.indicators(1);
    expect(items.first.progressPercent, 20.0);
    expect(items.first.fraction, closeTo(0.2, 0.001));
  });

  test('assignments hits the nested URL and parses', () async {
    final items = await repo.assignments(1);
    expect(items.first.userName, 'Jane');
    expect(stub.requested, contains('/projects/1/assignments/'));
  });
}
