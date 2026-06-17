import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/api_exception.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/auth/auth_repository.dart';

void main() {
  late InMemoryTokenStore store;
  late DioAdapter adapter;
  late AuthRepository repo;

  setUp(() {
    store = InMemoryTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AuthRepository(ApiClient(store, dio: dio), store);
  });

  test('login stores tokens and returns the user', () async {
    adapter.onPost(
      '/auth/login/',
      (server) => server.reply(200, {
        'access': 'a1',
        'refresh': 'r1',
        'user': {
          'id': 7,
          'full_name': 'Jane Officer',
          'email': 'jane@x.org',
          'role': 'officer',
          'ngo_id': 1,
        },
      }),
      data: {'email': 'jane@x.org', 'password': 'S3curePass!'},
    );

    final user = await repo.login('jane@x.org', 'S3curePass!');

    expect(user.id, 7);
    expect(user.role, 'officer');
    expect(await store.readAccess(), 'a1');
    expect(await store.readRefresh(), 'r1');
    expect((await store.readUser())?['email'], 'jane@x.org');
  });

  test('login maps the {error, code} envelope to ApiException', () async {
    adapter.onPost(
      '/auth/login/',
      (server) => server.reply(401, {
        'error': 'No active account found with the given credentials',
        'code': 'no_active_account',
      }),
      data: {'email': 'jane@x.org', 'password': 'wrong'},
    );

    expect(
      () => repo.login('jane@x.org', 'wrong'),
      throwsA(isA<ApiException>()
          .having((e) => e.code, 'code', 'no_active_account')),
    );
  });

  test('logout clears local tokens even when the API call fails', () async {
    await store.saveTokens(access: 'a1', refresh: 'r1');
    adapter.onPost(
      '/auth/logout/',
      (server) => server.reply(400, {'error': 'bad', 'code': 'x'}),
      data: {'refresh': 'r1'},
    );

    await repo.logout();

    expect(await store.readAccess(), isNull);
    expect(await store.readRefresh(), isNull);
  });
}
