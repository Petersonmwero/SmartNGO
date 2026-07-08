import 'package:go_router/go_router.dart';

import '../features/analytics/screens/analytics_dashboard_screen.dart';
import '../features/auth/auth_provider.dart';
import '../features/auth/screens/forgot_password_screen.dart';
import '../features/auth/screens/login_screen.dart';
import '../features/auth/screens/profile_screen.dart';
import '../features/auth/screens/register_screen.dart';
import '../features/beneficiaries/screens/beneficiary_list_screen.dart';
import '../features/dashboard/screens/dashboard_screen.dart';
import '../features/ngos/screens/ngo_management_screen.dart';
import '../features/projects/screens/create_project_screen.dart';
import '../features/projects/screens/projects_list_screen.dart';
import '../features/reports/screens/report_detail_screen.dart';
import '../features/reports/screens/reports_list_screen.dart';
import '../features/splash/splash_screen.dart';
import '../features/users/screens/user_management_screen.dart';
import '../shared/widgets/app_shell.dart';

GoRouter buildRouter(AuthProvider auth) => GoRouter(
      refreshListenable: auth,
      initialLocation: '/splash',
      redirect: (context, state) {
        final loc = state.matchedLocation;

        // /splash manages its own transition — never redirect away from it here.
        if (loc == '/splash') return null;

        final status = auth.status;

        // Still bootstrapping — send to splash until resolved.
        if (status == AuthStatus.unknown) return '/splash';

        final isPublic = const ['/login', '/register', '/forgot-password']
            .any((p) => loc == p);

        if (status == AuthStatus.unauthenticated && !isPublic) return '/login';
        if (status == AuthStatus.authenticated && isPublic) return '/';

        // Admin-only route guard.
        if (auth.user?.role != 'admin' &&
            (loc.startsWith('/users') || loc.startsWith('/ngos'))) {
          return '/';
        }

        return null;
      },
      routes: [
        // ── Auth-flow routes (no shell, full-screen) ──────────────────────
        GoRoute(
          path: '/splash',
          builder: (_, _) => const SplashScreen(),
        ),
        GoRoute(
          path: '/login',
          builder: (_, _) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (_, _) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (_, _) => const ForgotPasswordScreen(),
        ),

        // ── Feature screens pushed on top of the shell (no nav bar) ──────
        GoRoute(
          path: '/analytics',
          builder: (_, _) => const AnalyticsDashboardScreen(),
        ),
        GoRoute(
          path: '/users',
          builder: (_, _) => const UserManagementScreen(),
        ),
        GoRoute(
          path: '/ngos',
          builder: (_, _) => const NgoManagementScreen(),
        ),
        GoRoute(
          path: '/projects/new',
          builder: (_, _) => const CreateProjectScreen(),
        ),
        GoRoute(
          path: '/reports/:id',
          builder: (_, state) => ReportDetailScreen(
            reportId: int.parse(state.pathParameters['id']!),
          ),
        ),

        // ── Main shell (bottom nav bar) ───────────────────────────────────
        ShellRoute(
          builder: (context, state, child) =>
              AppShell(location: state.matchedLocation, child: child),
          routes: [
            GoRoute(path: '/', builder: (_, _) => const DashboardScreen()),
            GoRoute(path: '/projects', builder: (_, _) => const ProjectsListScreen()),
            GoRoute(path: '/reports', builder: (_, _) => const ReportsListScreen()),
            GoRoute(path: '/people', builder: (_, _) => const BeneficiaryListScreen()),
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    );
