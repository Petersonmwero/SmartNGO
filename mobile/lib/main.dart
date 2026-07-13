import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'core/token_storage.dart';
import 'features/analytics/analytics_repository.dart';
import 'features/auth/auth_provider.dart';
import 'features/auth/auth_repository.dart';
import 'features/beneficiaries/beneficiary_repository.dart';
import 'features/ngos/ngo_repository.dart';
import 'features/notifications/notification_repository.dart';
import 'features/notifications/notifications_provider.dart';
import 'features/projects/project_repository.dart';
import 'features/reports/draft_store.dart';
import 'features/reports/report_repository.dart';
import 'features/users/user_repository.dart';

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
        // sqflite has no web implementation; web (dev/demo target) keeps
        // drafts in memory for the browser session only.
        Provider<DraftStore>(
          create: (_) => kIsWeb ? InMemoryDraftStore() : SqfliteDraftStore(),
        ),
        Provider<BeneficiaryRepository>(create: (_) => BeneficiaryRepository(_apiClient)),
        Provider<AnalyticsRepository>(create: (_) => AnalyticsRepository(_apiClient)),
        Provider<UserRepository>(create: (_) => UserRepository(_apiClient)),
        Provider<NgoRepository>(create: (_) => NgoRepository(_apiClient)),
        ChangeNotifierProvider<NotificationsProvider>(
          create: (_) => NotificationsProvider(NotificationRepository(_apiClient)),
        ),
      ],
      child: Builder(
        builder: (context) {
          final authProvider = context.read<AuthProvider>();
          final router = buildRouter(authProvider);
          return MaterialApp.router(
            title: 'Smart NGO',
            debugShowCheckedModeBanner: false,
            theme: buildAppTheme(),
            routerConfig: router,
          );
        },
      ),
    );
  }
}
