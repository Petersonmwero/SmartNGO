import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../shared/widgets/kpi_card.dart';
import '../../auth/auth_provider.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../../beneficiaries/screens/beneficiary_list_screen.dart';
import '../../notifications/notifications_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../projects/project_repository.dart';
import '../../projects/screens/projects_list_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int? _projectCount;
  int? _beneficiaryCount;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadCounts());
  }

  Future<void> _loadCounts() async {
    final projects = context.read<ProjectRepository>();
    final beneficiaries = context.read<BeneficiaryRepository>();
    context.read<NotificationsProvider>().load();
    try {
      final p = await projects.list();
      final b = await beneficiaries.count();
      if (!mounted) return;
      setState(() {
        _projectCount = p.count;
        _beneficiaryCount = b;
      });
    } catch (_) {
      // Counts simply stay as placeholders on failure.
    }
  }

  String _fmt(int? value) => value?.toString() ?? '—';

  void _open(Widget screen) {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen))
        .then((_) => _loadCounts());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final unread = context.watch<NotificationsProvider>().unread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => _open(const NotificationsScreen()),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: () => context.read<AuthProvider>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadCounts,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Welcome${user != null ? ', ${user.fullName}' : ''}',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            if (user != null)
              Text(user.roleLabel,
                  style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                KpiCard(
                  label: 'Projects',
                  value: _fmt(_projectCount),
                  icon: Icons.work_outline,
                  onTap: () => _open(const ProjectsListScreen()),
                ),
                KpiCard(
                  label: 'Beneficiaries',
                  value: _fmt(_beneficiaryCount),
                  icon: Icons.people_outline,
                  onTap: () => _open(const BeneficiaryListScreen()),
                ),
                KpiCard(
                  label: 'Notifications',
                  value: _fmt(unread),
                  icon: Icons.notifications_outlined,
                  onTap: () => _open(const NotificationsScreen()),
                ),
                const KpiCard(
                  label: 'Reports',
                  value: '—',
                  icon: Icons.description_outlined,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
