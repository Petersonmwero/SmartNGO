import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/beneficiaries/beneficiary_repository.dart';

class BeneficiaryStub implements HttpClientAdapter {
  final List<String> calls = [];

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(jsonEncode(body), status, headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      });

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add('${options.method} ${options.path}');
    if (options.method == 'GET' && options.path == '/beneficiaries/') {
      return _json({
        'count': 2,
        'results': [
          {'id': 1, 'name': 'Amani', 'gender': 'female', 'age': 5, 'project': 1, 'is_active': true},
          {'id': 2, 'name': 'Baraka', 'gender': 'male', 'age': 8, 'project': 1, 'is_active': true},
        ],
      }, 200);
    }
    if (options.method == 'POST') {
      return _json(
          {'id': 9, 'name': 'New', 'gender': 'other', 'project': 1, 'is_active': true},
          201);
    }
    return ResponseBody.fromString('', 204);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late BeneficiaryRepository repo;
  late BeneficiaryStub stub;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    stub = BeneficiaryStub();
    dio.httpClientAdapter = stub;
    repo = BeneficiaryRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('list parses beneficiaries with computed age', () async {
    final page = await repo.list(projectId: 1);
    expect(page.count, 2);
    expect(page.results.first.name, 'Amani');
    expect(page.results.first.age, 5);
  });

  test('count returns the paginated count', () async {
    expect(await repo.count(), 2);
  });

  test('create posts and returns the new beneficiary', () async {
    final b = await repo.create(projectId: 1, name: 'New', gender: 'other');
    expect(b.id, 9);
    expect(stub.calls, contains('POST /beneficiaries/'));
  });

  test('delete hits the soft-delete endpoint', () async {
    await repo.delete(3);
    expect(stub.calls, contains('DELETE /beneficiaries/3/'));
  });
}
