import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../features/auth/auth_provider.dart';
import '../../features/notifications/notifications_provider.dart';

/// Bottom-navigation shell used by GoRouter's [ShellRoute].
///
/// [child] is the currently matched route's widget (provided by GoRouter).
/// [location] is the current route path, used to highlight the active tab.
class AppShell extends StatefulWidget {
  final Widget child;
  final String location;

  const AppShell({super.key, required this.child, required this.location});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NotificationsProvider>().load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role ?? '';
    final canOps = role != 'donor';

    final tabs = <_Tab>[
      const _Tab(path: '/', icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Home'),
      const _Tab(path: '/projects', icon: Icons.work_outline, activeIcon: Icons.work, label: 'Projects'),
      if (canOps)
        const _Tab(path: '/reports', icon: Icons.description_outlined, activeIcon: Icons.description, label: 'Reports'),
      if (canOps)
        const _Tab(path: '/people', icon: Icons.people_outline, activeIcon: Icons.people, label: 'People'),
      const _Tab(path: '/profile', icon: Icons.person_outline, activeIcon: Icons.person, label: 'Profile'),
    ];

    final selectedIndex = _resolveIndex(widget.location, tabs);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          // Official gold rule along the top of the navigation bar.
          border: const Border(
            top: BorderSide(color: AppColors.accent, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black26.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (i) => context.go(tabs[i].path),
          destinations: [
            for (final tab in tabs)
              NavigationDestination(
                icon: Icon(tab.icon),
                selectedIcon: Icon(tab.activeIcon),
                label: tab.label,
              ),
          ],
        ),
      ),
    );
  }

  /// Find which tab index corresponds to the current [location].
  int _resolveIndex(String location, List<_Tab> tabs) {
    // Exact match first (handles '/' correctly).
    for (int i = 0; i < tabs.length; i++) {
      if (tabs[i].path == location) return i;
    }
    // Prefix match for sub-paths (e.g. location='/projects' with path='/projects').
    for (int i = 0; i < tabs.length; i++) {
      final p = tabs[i].path;
      if (p != '/' && location.startsWith(p)) return i;
    }
    return 0;
  }
}

class _Tab {
  final String path;
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _Tab({
    required this.path,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
