import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/kpi_card.dart';
import '../../../shared/widgets/project_progress_bar.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../analytics/analytics_repository.dart';
import '../../auth/auth_provider.dart';
import '../../auth/models/user.dart';
import '../../beneficiaries/screens/register_beneficiary_screen.dart';
import '../../notifications/models/notification.dart';
import '../../notifications/notifications_provider.dart';
import '../../notifications/screens/notifications_screen.dart';
import '../../projects/models/project.dart';
import '../../projects/project_repository.dart';
import '../../projects/screens/project_detail_screen.dart';
import '../../reports/draft_store.dart';
import '../../reports/screens/submit_report_screen.dart';

/// Role-aware home screen: greeting header, KPI row, quick actions,
/// recent projects, and a recent-activity feed.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<Project> _recentProjects = const [];
  int _localDrafts = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final stats = await context.read<AnalyticsRepository>().dashboard();
      if (!mounted) return;
      setState(() => _stats = stats);
    } catch (_) {}
    if (!mounted) return;
    try {
      final projects = await context.read<ProjectRepository>().list();
      if (!mounted) return;
      setState(() => _recentProjects = projects.results.take(3).toList());
    } catch (_) {}
    if (!mounted) return;
    try {
      final drafts = await context.read<DraftStore>().list();
      if (!mounted) return;
      setState(() => _localDrafts = drafts.length);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final notifications = context.watch<NotificationsProvider>();

    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () async {
          final notifications = context.read<NotificationsProvider>();
          await _load();
          await notifications.load();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(user: user, unread: notifications.unread),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KpiRow(
                    role: user?.role ?? '',
                    stats: _stats,
                    localDrafts: _localDrafts,
                  ),
                  const SizedBox(height: 8),
                  const SectionHeader('Quick Actions'),
                  _QuickActionsGrid(role: user?.role ?? ''),
                  SectionHeader(
                    'Recent Projects',
                    actionLabel: 'See all',
                    onAction: () => context.go('/projects'),
                  ),
                  if (_recentProjects.isEmpty)
                    _placeholderCard(context, 'No projects yet.')
                  else
                    for (final p in _recentProjects)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _MiniProjectCard(project: p),
                      ),
                  const SectionHeader('Recent Activity'),
                  if (notifications.items.isEmpty)
                    _placeholderCard(context, 'No recent activity.')
                  else
                    Card(
                      child: Column(
                        children: [
                          for (final n in notifications.items.take(5))
                            _ActivityItem(notification: n),
                        ],
                      ),
                    ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard(BuildContext context, String message) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text(message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted)),
        ),
      ),
    );
  }
}

// ── Green greeting header ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final User? user;
  final int unread;
  const _Header({required this.user, required this.unread});

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final firstName = user?.firstName.trim().isNotEmpty == true
        ? user!.firstName.trim()
        : 'there';
    final initials = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim()[0].toUpperCase())
        .join();

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 20, 12, 24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$_greeting, $firstName! 👋',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 22,
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (user != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      user!.roleLabel,
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ],
            ),
          ),
          IconButton(
            tooltip: 'Notifications',
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.accent,
              child: const Icon(Icons.notifications_outlined,
                  color: Colors.white),
            ),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          if (initials.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4, right: 8),
              child: CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.accent,
                child: Text(
                  initials,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── KPI row (role-aware) ──────────────────────────────────────────────────

class _KpiRow extends StatelessWidget {
  final String role;
  final DashboardStats? stats;
  final int localDrafts;

  const _KpiRow({
    required this.role,
    required this.stats,
    required this.localDrafts,
  });

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final projects = s?.projects.total.toString() ?? '—';
    final beneficiaries = s?.beneficiaries.toString() ?? '—';
    final pending = s?.reports.submitted.toString() ?? '—';
    final approved = s?.reports.approved.toString() ?? '—';
    final totalReports = s == null
        ? '—'
        : '${s.reports.draft + s.reports.submitted + s.reports.approved}';

    final kpis = switch (role) {
      'officer' => [
          ('Assigned Projects', projects, Icons.work_outline),
          ('My Reports', totalReports, Icons.description_outlined),
          ('Drafts', '$localDrafts', Icons.edit_note_outlined),
        ],
      'donor' => [
          ('Funded Projects', projects, Icons.work_outline),
          ('Beneficiaries', beneficiaries, Icons.people_outline),
          ('Approved Reports', approved, Icons.verified_outlined),
        ],
      // Manager and admin share the operational overview.
      _ => [
          ('Projects', projects, Icons.work_outline),
          ('Beneficiaries', beneficiaries, Icons.people_outline),
          ('Pending Reports', pending, Icons.pending_actions_outlined),
        ],
    };

    return Row(
      children: [
        for (final (label, value, icon) in kpis) ...[
          Expanded(child: KpiCard(label: label, value: value, icon: icon)),
          if (kpis.last.$1 != label) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

// ── Quick actions 2×2 grid ────────────────────────────────────────────────

class _QuickActionsGrid extends StatelessWidget {
  final String role;
  const _QuickActionsGrid({required this.role});

  @override
  Widget build(BuildContext context) {
    final actions = switch (role) {
      'admin' => [
          ('Manage Users', Icons.manage_accounts_outlined,
              () => context.push('/users')),
          ('Manage NGOs', Icons.domain_outlined, () => context.push('/ngos')),
          ('View Analytics', Icons.bar_chart_outlined,
              () => context.push('/analytics')),
          ('View Reports', Icons.description_outlined,
              () => context.go('/reports')),
        ],
      'officer' => [
          ('Submit Report', Icons.post_add_outlined,
              () => _openSubmitReport(context)),
          ('My Reports', Icons.description_outlined,
              () => context.go('/reports')),
          ('Add Beneficiary', Icons.person_add_outlined,
              () => _openRegisterBeneficiary(context)),
          ('My Profile', Icons.person_outline, () => context.go('/profile')),
        ],
      'donor' => [
          ('View Projects', Icons.work_outline, () => context.go('/projects')),
          ('View Analytics', Icons.bar_chart_outlined,
              () => context.push('/analytics')),
          ('Notifications', Icons.notifications_outlined,
              () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => const NotificationsScreen()))),
          ('My Profile', Icons.person_outline, () => context.go('/profile')),
        ],
      // Manager default.
      _ => [
          ('New Project', Icons.add_business_outlined,
              () => context.push('/projects/new')),
          ('Submit Report', Icons.post_add_outlined,
              () => _openSubmitReport(context)),
          ('Add Beneficiary', Icons.person_add_outlined,
              () => _openRegisterBeneficiary(context)),
          ('Analytics', Icons.bar_chart_outlined,
              () => context.push('/analytics')),
        ],
    };

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.6,
      children: [
        for (final (label, icon, onTap) in actions)
          Card(
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, size: 18, color: AppColors.primary),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        label,
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  static void _openSubmitReport(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const SubmitReportScreen()),
    );
  }

  static void _openRegisterBeneficiary(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterBeneficiaryScreen()),
    );
  }
}

// ── Recent projects mini card ─────────────────────────────────────────────

class _MiniProjectCard extends StatelessWidget {
  final Project project;
  const _MiniProjectCard({required this.project});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              projectId: project.id,
              title: project.projectName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(project.status),
                ],
              ),
              const SizedBox(height: 12),
              ProjectProgressBar(project.timelineProgress, label: 'Timeline'),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Activity feed item ────────────────────────────────────────────────────

class _ActivityItem extends StatelessWidget {
  final AppNotification notification;
  const _ActivityItem({required this.notification});

  /// Dot color inferred from the notification's subject: green for team
  /// assignments, amber for deadlines, blue for approvals.
  Color get _dotColor {
    final text = '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) return AppColors.info;
    if (text.contains('due') ||
        text.contains('deadline') ||
        text.contains('overdue') ||
        text.contains('budget')) {
      return AppColors.accent;
    }
    if (text.contains('assign') || text.contains('added')) {
      return AppColors.success;
    }
    return AppColors.muted;
  }

  String get _timestamp {
    final iso = notification.createdAt;
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      return '${diff.inDays}d';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: _dotColor, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              notification.title,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _timestamp,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
