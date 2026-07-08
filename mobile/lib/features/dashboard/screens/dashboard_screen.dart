import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../auth/auth_provider.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../../notifications/notifications_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../projects/project_repository.dart';

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final projects = context.read<ProjectRepository>();
    final beneficiaries = context.read<BeneficiaryRepository>();
    try {
      final p = await projects.list();
      final b = await beneficiaries.count();
      if (!mounted) return;
      setState(() {
        _projectCount = p.count;
        _beneficiaryCount = b;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final unread = context.watch<NotificationsProvider>().unread;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart NGO'),
        actions: [
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.notifications_outlined),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _GreetingCard(user: user),
            const SizedBox(height: 20),
            Text('Overview',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: KpiCard(
                    label: 'Projects',
                    value: _projectCount?.toString() ?? '—',
                    icon: Icons.work_outline,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KpiCard(
                    label: 'Beneficiaries',
                    value: _beneficiaryCount?.toString() ?? '—',
                    icon: Icons.people_outline,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: KpiCard(
                    label: 'Alerts',
                    value: '$unread',
                    icon: Icons.notifications_outlined,
                    color: unread > 0
                        ? AppColors.accent
                        : AppColors.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _InfoCard(
              icon: Icons.tips_and_updates_outlined,
              message: user?.role == 'donor'
                  ? 'Browse Projects to view funded initiatives and track their progress.'
                  : 'Use the bottom navigation to submit field reports, track milestones, and manage beneficiaries.',
            ),
          ],
        ),
      ),
    );
  }
}

class _GreetingCard extends StatelessWidget {
  final dynamic user;
  const _GreetingCard({required this.user});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String get _firstName {
    if (user == null) return 'there';
    final name = (user.fullName as String).trim();
    return name.isEmpty ? 'there' : name.split(' ').first;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $_firstName!',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(color: Colors.white),
                ),
                if (user != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    user.roleLabel as String,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                        ),
                  ),
                ],
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.eco_rounded,
                color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String message;
  const _InfoCard({required this.icon, required this.message});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.accent, size: 24),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
