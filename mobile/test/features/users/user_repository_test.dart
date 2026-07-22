import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/users/user_repository.dart';

/// Records method + path + body so we can assert URL construction and payloads.
class StubAdapter implements HttpClientAdapter {
  final List<String> requested = [];
  String? lastMethod;
  Map<String, dynamic>? lastBody;

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
    lastMethod = options.method;
    lastBody = options.data is Map<String, dynamic>
        ? options.data as Map<String, dynamic>
        : null;
    if (options.path == '/users/') {
      return _json({
        'count': 1,
        'next': null,
        'previous': null,
        'results': [
          {
            'id': 5,
            'first_name': 'Ada',
            'last_name': 'Achieng',
            'email': 'ada@demo.ngo',
            'role': 'officer',
            'phone': '0700000000',
            'is_active': true,
            'created_at': '2026-01-01T00:00:00Z',
          },
        ],
      });
    }
    return _json({'id': 5, 'is_active': true});
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late UserRepository repo;
  late StubAdapter stub;

  setUp(() {
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    stub = StubAdapter();
    dio.httpClientAdapter = stub;
    repo = UserRepository(ApiClient(InMemoryTokenStore(), dio: dio));
  });

  test('list parses users and keeps split names', () async {
    final page = await repo.list();
    final u = page.results.single;
    expect(u.id, 5);
    expect(u.firstName, 'Ada');
    expect(u.lastName, 'Achieng');
    expect(u.fullName, 'Ada Achieng');
    expect(u.role, 'officer');
    expect(u.phone, '0700000000');
  });

  test('update PATCHes the user and sends editable fields only', () async {
    await repo.update(
      id: 5,
      firstName: 'Ada',
      lastName: 'Okoth',
      role: 'manager',
      phone: '0711111111',
    );
    expect(stub.requested, contains('/users/5/'));
    expect(stub.lastMethod, 'PATCH');
    expect(stub.lastBody, {
      'first_name': 'Ada',
      'last_name': 'Okoth',
      'role': 'manager',
      'phone': '0711111111',
    });
    // Email and password are never part of an edit payload.
    expect(stub.lastBody!.containsKey('email'), isFalse);
    expect(stub.lastBody!.containsKey('password'), isFalse);
  });

  test('toggleActive hits the toggle-active action', () async {
    await repo.toggleActive(5);
    expect(stub.requested, contains('/users/5/toggle-active/'));
    expect(stub.lastMethod, 'PATCH');
  });
}
