import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';

/// Deterministic adapter for testing the 401 -> refresh -> retry sequence,
/// which http_mock_adapter cannot express reliably for a repeated route.
class _ScriptedAdapter implements HttpClientAdapter {
  final bool refreshSucceeds;
  int projectCalls = 0;
  int refreshCalls = 0;

  _ScriptedAdapter({this.refreshSucceeds = true});

  ResponseBody _json(Map<String, dynamic> body, int status) =>
      ResponseBody.fromString(
        jsonEncode(body),
        status,
        headers: {
          Headers.contentTypeHeader: [Headers.jsonContentType],
        },
      );

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final path = options.path;
    if (path.contains('/auth/token/refresh/')) {
      refreshCalls++;
      return refreshSucceeds
          ? _json({'access': 'new-access'}, 200)
          : _json({'error': 'invalid', 'code': 'token_invalid'}, 401);
    }
    if (path.contains('/projects/')) {
      projectCalls++;
      return projectCalls == 1
          ? _json({'error': 'expired'}, 401)
          : _json({'results': []}, 200);
    }
    return _json({}, 200);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late InMemoryTokenStore store;
  late Dio dio;
  late DioAdapter adapter;
  var authFailed = false;

  setUp(() {
    store = InMemoryTokenStore();
    dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    adapter = DioAdapter(dio: dio);
    authFailed = false;
    // Constructing ApiClient installs the interceptors on `dio`.
    ApiClient(store, dio: dio, onAuthFailure: () => authFailed = true);
  });

  test('attaches bearer token to authenticated requests', () async {
    await store.saveTokens(access: 'abc', refresh: 'r1');
    adapter.onGet('/projects/', (server) => server.reply(200, {'results': []}));

    final res = await dio.get('/projects/');

    expect(res.statusCode, 200);
    expect(res.requestOptions.headers['Authorization'], 'Bearer abc');
  });

  test('does not attach token to public auth paths', () async {
    await store.saveTokens(access: 'abc', refresh: 'r1');
    adapter.onPost('/auth/login/', (server) => server.reply(200, {}),
        data: {'email': 'a@b.c', 'password': 'x'});

    final res =
        await dio.post('/auth/login/', data: {'email': 'a@b.c', 'password': 'x'});

    expect(res.requestOptions.headers.containsKey('Authorization'), isFalse);
  });

  test('on 401 it refreshes the token and retries the request', () async {
    await store.saveTokens(access: 'expired', refresh: 'good-refresh');
    final scripted = _ScriptedAdapter(refreshSucceeds: true);
    dio.httpClientAdapter = scripted;

    final res = await dio.get('/projects/');

    expect(res.statusCode, 200);
    expect(scripted.projectCalls, 2); // original + retry
    expect(scripted.refreshCalls, 1);
    expect(await store.readAccess(), 'new-access');
    expect(authFailed, isFalse);
  });

  test('on failed refresh it clears tokens and signals auth failure', () async {
    await store.saveTokens(access: 'expired', refresh: 'bad-refresh');
    dio.httpClientAdapter = _ScriptedAdapter(refreshSucceeds: false);

    await expectLater(dio.get('/projects/'), throwsA(isA<DioException>()));
    expect(await store.readAccess(), isNull);
    expect(authFailed, isTrue);
  });
}
