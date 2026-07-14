import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_theme_data.dart';
import '../../../core/theme.dart';
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

/// Role-aware home screen: gradient greeting header with an inline stats
/// strip, horizontally scrollable quick actions, recent projects, and a
/// recent-activity feed — layered like a modern banking app.
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
          final provider = context.read<NotificationsProvider>();
          await _load();
          await provider.load();
        },
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            _Header(
              user: user,
              unread: notifications.unread,
              stats: _stats,
              localDrafts: _localDrafts,
            ),
            // Cream sheet with rounded top corners pulled up over the
            // gradient header for a layered-card effect.
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SectionHeader('Quick Actions'),
                    _QuickActionsRow(role: user?.role ?? ''),
                    const SizedBox(height: 8),
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
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _MiniProjectCard(project: p),
                        ),
                    const SizedBox(height: 8),
                    SectionHeader(
                      'Recent Activity',
                      actionLabel: 'See all',
                      onAction: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                    ),
                    if (notifications.items.isEmpty)
                      _placeholderCard(context, 'No recent activity.')
                    else
                      _softCard(
                        child: Column(
                          children: [
                            for (final (i, n)
                                in notifications.items.take(5).indexed) ...[
                              if (i > 0)
                                const Divider(height: 1, indent: 48),
                              _ActivityItem(notification: n),
                            ],
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholderCard(BuildContext context, String message) {
    return _softCard(
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

/// White rounded container with the dashboard's soft drop shadow.
Widget _softCard({required Widget child, double radius = 12}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );
}

// ── Gradient header with stats strip ──────────────────────────────────────

class _Header extends StatelessWidget {
  final User? user;
  final int unread;
  final DashboardStats? stats;
  final int localDrafts;

  const _Header({
    required this.user,
    required this.unread,
    required this.stats,
    required this.localDrafts,
  });

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  /// Role-aware trio shown in the stats strip.
  List<(String, String)> get _stripStats {
    final s = stats;
    final projects = s?.projects.total.toString() ?? '—';
    final beneficiaries = s?.beneficiaries.toString() ?? '—';
    final pending = s?.reports.submitted.toString() ?? '—';
    final approved = s?.reports.approved.toString() ?? '—';
    final totalReports = s == null
        ? '—'
        : '${s.reports.draft + s.reports.submitted + s.reports.approved}';

    return switch (user?.role) {
      'officer' => [
          (projects, 'Projects'),
          (totalReports, 'Reports'),
          ('$localDrafts', 'Drafts'),
        ],
      'donor' => [
          (projects, 'Projects'),
          (beneficiaries, 'Beneficiaries'),
          (approved, 'Approved'),
        ],
      _ => [
          (projects, 'Projects'),
          (beneficiaries, 'Beneficiaries'),
          (pending, 'Pending'),
        ],
    };
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
      decoration:
          const BoxDecoration(gradient: AppThemeData.headerGradient),
      // Extra bottom padding hides under the overlapping cream sheet.
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.paddingOf(context).top + 16, 20, 24 + 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Smart NGO M&E',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.6),
                          ),
                    ),
                    const SizedBox(height: 4),
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
                                fontSize: 11,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                children: [
                  _BellButton(unread: unread),
                  const SizedBox(height: 6),
                  if (initials.isNotEmpty)
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accent,
                      child: Text(
                        initials,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 18),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Stats summary strip.
          Container(
            padding:
                const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                for (final (i, item) in _stripStats.indexed) ...[
                  if (i > 0)
                    Container(
                      width: 1,
                      height: 32,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          item.$1,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: 20,
                                color: AppColors.accentLight,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.$2,
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                fontSize: 11,
                                color: Colors.white.withValues(alpha: 0.7),
                              ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BellButton extends StatelessWidget {
  final int unread;
  const _BellButton({required this.unread});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          const Icon(Icons.notifications_outlined,
              color: Colors.white, size: 26),
          if (unread > 0)
            Positioned(
              top: -4,
              right: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16),
                decoration: const BoxDecoration(
                  color: AppColors.error,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$unread',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9,
                      fontWeight: FontWeight.w700),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Quick actions: horizontal scrollable chips ────────────────────────────

enum _ChipStyle { primary, secondary, neutral }

class _QuickActionsRow extends StatelessWidget {
  final String role;
  const _QuickActionsRow({required this.role});

  @override
  Widget build(BuildContext context) {
    final actions = switch (role) {
      'officer' => [
          ('Submit Report', Icons.post_add_outlined, _ChipStyle.primary,
              () => _openSubmitReport(context)),
          ('My Reports', Icons.description_outlined, _ChipStyle.primary,
              () => context.go('/reports')),
          ('Add Beneficiary', Icons.person_add_outlined, _ChipStyle.secondary,
              () => _openRegisterBeneficiary(context)),
          ('My Projects', Icons.work_outline, _ChipStyle.secondary,
              () => context.go('/projects')),
          ('Notifications', Icons.notifications_outlined,
              _ChipStyle.secondary, () => _openNotifications(context)),
        ],
      'admin' => [
          ('Manage Users', Icons.manage_accounts_outlined, _ChipStyle.primary,
              () => context.push('/users')),
          ('Manage NGOs', Icons.domain_outlined, _ChipStyle.primary,
              () => context.push('/ngos')),
          ('Analytics', Icons.bar_chart_outlined, _ChipStyle.secondary,
              () => context.push('/analytics')),
          ('View Reports', Icons.description_outlined, _ChipStyle.secondary,
              () => context.go('/reports')),
          ('New Project', Icons.add_business_outlined, _ChipStyle.secondary,
              () => context.push('/projects/new')),
        ],
      'donor' => [
          ('View Projects', Icons.work_outline, _ChipStyle.primary,
              () => context.go('/projects')),
          ('View Reports', Icons.description_outlined, _ChipStyle.primary,
              () => context.go('/reports')),
          ('Analytics', Icons.bar_chart_outlined, _ChipStyle.secondary,
              () => context.push('/analytics')),
          ('My Profile', Icons.person_outline, _ChipStyle.secondary,
              () => context.go('/profile')),
        ],
      // Manager default.
      _ => [
          ('New Project', Icons.add_business_outlined, _ChipStyle.primary,
              () => context.push('/projects/new')),
          ('Submit Report', Icons.post_add_outlined, _ChipStyle.primary,
              () => _openSubmitReport(context)),
          ('Add Beneficiary', Icons.person_add_outlined, _ChipStyle.secondary,
              () => _openRegisterBeneficiary(context)),
          ('Analytics', Icons.bar_chart_outlined, _ChipStyle.secondary,
              () => context.push('/analytics')),
          ('Notifications', Icons.notifications_outlined,
              _ChipStyle.secondary, () => _openNotifications(context)),
          ('My Profile', Icons.person_outline, _ChipStyle.neutral,
              () => context.go('/profile')),
        ],
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final (label, icon, style, onTap) in actions)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _QuickActionChip(
                  label: label, icon: icon, style: style, onTap: onTap),
            ),
        ],
      ),
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

  static void _openNotifications(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificationsScreen()),
    );
  }
}

class _QuickActionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final _ChipStyle style;
  final VoidCallback onTap;

  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.style,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final (iconBg, iconColor) = switch (style) {
      _ChipStyle.primary => (AppColors.primary, Colors.white),
      _ChipStyle.secondary =>
        (AppColors.accent.withValues(alpha: 0.1), AppColors.accent),
      _ChipStyle.neutral => (AppColors.neutralTint, AppColors.muted),
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: 100,
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.charcoal,
                      height: 1.15,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Recent projects mini card with status accent bar ──────────────────────

class _MiniProjectCard extends StatelessWidget {
  final Project project;
  const _MiniProjectCard({required this.project});

  String get _budget {
    final value = double.tryParse(project.budget);
    if (value == null) return project.budget;
    if (value >= 1000000) {
      return 'KES ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return 'KES ${(value / 1000).toStringAsFixed(0)}K';
    return 'KES ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    final (accent, _) = StatusBadge.colorsFor(project.status);
    return _softCard(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ProjectDetailScreen(
                  projectId: project.id,
                  title: project.projectName,
                ),
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(width: 4, color: accent),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  project.projectName,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(fontSize: 14),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              StatusBadge(project.status),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ProjectProgressBar(project.timelineProgress,
                              label: 'Timeline', height: 4),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.event_outlined,
                                  size: 12, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                project.endDate ?? '—',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        fontSize: 11,
                                        color: AppColors.muted),
                              ),
                              const SizedBox(width: 14),
                              const Icon(Icons.payments_outlined,
                                  size: 12, color: AppColors.muted),
                              const SizedBox(width: 4),
                              Text(
                                _budget,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        fontSize: 11,
                                        color: AppColors.muted),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

  /// Icon + color inferred from the notification's subject: green person
  /// for assignments, amber clock for deadlines, blue check for approvals,
  /// red chart for budget alerts.
  (IconData, Color) get _iconSpec {
    final text = '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) {
      return (Icons.check_circle_outline, AppColors.info);
    }
    if (text.contains('budget')) {
      return (Icons.insert_chart_outlined, AppColors.danger);
    }
    if (text.contains('due') ||
        text.contains('deadline') ||
        text.contains('overdue')) {
      return (Icons.schedule, AppColors.accent);
    }
    if (text.contains('assign') || text.contains('added')) {
      return (Icons.person_outline, AppColors.success);
    }
    return (Icons.notifications_outlined, AppColors.muted);
  }

  String get _timestamp {
    final iso = notification.createdAt;
    if (iso == null) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _iconSpec;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontSize: 13,
                        color: AppColors.charcoal,
                        fontWeight: notification.isUnread
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_timestamp.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _timestamp,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
