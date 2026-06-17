import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/beneficiaries/beneficiary_repository.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/notifications/notification_repository.dart';
import 'features/notifications/notifications_provider.dart';
import 'features/projects/project_repository.dart';
import 'features/reports/report_repository.dart';

void main() {
  runApp(SmartNgoApp(store: SecureTokenStore()));
}

class SmartNgoApp extends StatefulWidget {
  final TokenStore store;
  const SmartNgoApp({super.key, required this.store});

  @override
  State<SmartNgoApp> createState() => _SmartNgoAppState();
}

class _SmartNgoAppState extends State<SmartNgoApp> {
  late final ApiClient _apiClient;
  late final AuthRepository _authRepository;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    // Wire the API client's auth-failure callback to the provider so a failed
    // token refresh drops the user back to the login screen.
    _apiClient = ApiClient(
      widget.store,
      onAuthFailure: () => _authProvider.onSessionExpired(),
    );
    _authRepository = AuthRepository(_apiClient, widget.store);
    _authProvider = AuthProvider(_authRepository)..bootstrap();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _apiClient),
        Provider<AuthRepository>.value(value: _authRepository),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        Provider<ProjectRepository>(create: (_) => ProjectRepository(_apiClient)),
        Provider<ReportRepository>(create: (_) => ReportRepository(_apiClient)),
        Provider<BeneficiaryRepository>(
            create: (_) => BeneficiaryRepository(_apiClient)),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) =>
              NotificationsProvider(NotificationRepository(_apiClient)),
        ),
      ],
      child: MaterialApp(
        title: 'Smart NGO',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        home: const _AuthGate(),
      ),
    );
  }
}

/// Shows the dashboard or login screen depending on auth state.
class _AuthGate extends StatelessWidget {
  const _AuthGate();

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        );
      case AuthStatus.authenticated:
        return const DashboardScreen();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}
