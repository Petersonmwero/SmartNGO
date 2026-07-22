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
    if (options.method == 'GET' && options.path == '/locations/kenya/') {
      final q = options.queryParameters;
      if (q.containsKey('counties')) {
        return _json({'status': 'success', 'data': ['Nairobi', 'Kisumu']}, 200);
      }
      if (q['county'] == 'Kisumu') {
        return _json({'status': 'success', 'data': ['Kisumu East', 'Seme']}, 200);
      }
      // Ward locations are scoped by (constituency, ward); check ward before
      // the bare-constituency (→ wards) case, matching the real API's order.
      if (q['ward'] == 'Nyalenda A' && q['constituency'] == 'Kisumu East') {
        return _json({'status': 'success', 'data': ['Nyalenda A', 'Nyalenda B']}, 200);
      }
      if (q['constituency'] == 'Kisumu East') {
        return _json({'status': 'success', 'data': ['Kolwa East', 'Nyalenda A']}, 200);
      }
      if (q['location'] == 'Nyalenda A') {
        return _json({'status': 'success', 'data': ['Nyalenda A1', 'Nyalenda A2']}, 200);
      }
      return _json({'status': 'success', 'data': []}, 200);
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

  test('kenya location lookups cascade through all five levels', () async {
    expect(await repo.kenyaCounties(), ['Nairobi', 'Kisumu']);
    expect(await repo.kenyaConstituencies('Kisumu'), ['Kisumu East', 'Seme']);
    expect(await repo.kenyaWards('Kisumu East'), ['Kolwa East', 'Nyalenda A']);
    expect(await repo.kenyaLocations('Kisumu East', 'Nyalenda A'),
        ['Nyalenda A', 'Nyalenda B']);
    expect(await repo.kenyaSubLocations('Nyalenda A'),
        ['Nyalenda A1', 'Nyalenda A2']);
    // Unknown names degrade to an empty list, not an error.
    expect(await repo.kenyaWards('Atlantis'), isEmpty);
  });
}
