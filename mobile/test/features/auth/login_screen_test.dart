import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:provider/provider.dart';
import 'package:smartngo/core/api_client.dart';
import 'package:smartngo/core/token_storage.dart';
import 'package:smartngo/features/auth/auth_provider.dart';
import 'package:smartngo/features/auth/auth_repository.dart';
import 'package:smartngo/features/auth/screens/login_screen.dart';

Widget _harness(AuthProvider auth, AuthRepository repo) {
  return MultiProvider(
    providers: [
      Provider<AuthRepository>.value(value: repo),
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
    ],
    child: MaterialApp(
      home: Consumer<AuthProvider>(
        builder: (_, a, _) => a.isAuthenticated
            ? const Scaffold(body: Text('DASHBOARD'))
            : const LoginScreen(),
      ),
    ),
  );
}

void main() {
  late DioAdapter adapter;
  late AuthRepository repo;
  late AuthProvider auth;

  setUp(() {
    final store = InMemoryTokenStore();
    final dio = Dio(BaseOptions(baseUrl: 'http://test/api/v1'));
    adapter = DioAdapter(dio: dio);
    repo = AuthRepository(ApiClient(store, dio: dio), store);
    auth = AuthProvider(repo);
  });

  testWidgets('shows validation errors for empty fields', (tester) async {
    await tester.pumpWidget(_harness(auth, repo));

    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pump();

    expect(find.text('Enter a valid email'), findsOneWidget);
    expect(find.text('Password must be at least 8 characters'), findsOneWidget);
  });

  testWidgets('successful login swaps to the dashboard', (tester) async {
    adapter.onPost(
      '/auth/login/',
      (server) => server.reply(200, {
        'access': 'a1',
        'refresh': 'r1',
        'user': {
          'id': 1,
          'full_name': 'Jane',
          'email': 'jane@x.org',
          'role': 'officer',
          'ngo_id': 1,
        },
      }),
      data: {'email': 'jane@x.org', 'password': 'S3curePass!'},
    );

    await tester.pumpWidget(_harness(auth, repo));
    await tester.enterText(find.byKey(const Key('email_field')), 'jane@x.org');
    await tester.enterText(
        find.byKey(const Key('password_field')), 'S3curePass!');
    await tester.tap(find.byKey(const Key('login_button')));
    await tester.pumpAndSettle();

    expect(find.text('DASHBOARD'), findsOneWidget);
  });
}
