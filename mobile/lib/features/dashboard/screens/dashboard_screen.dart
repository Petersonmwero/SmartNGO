import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/official_card.dart';
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
import '../../reports/screens/submit_report_screen.dart';

/// Official eCitizen-style home screen: government header with the Kenya
/// flag ribbon, a welcome notice, statistics, a quick-services grid, and
/// table-style recent projects / activity log sections.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<Project>? _recentProjects; // null while loading

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
      setState(() => _recentProjects = projects.results.take(4).toList());
    } catch (_) {
      setState(() => _recentProjects ??= const []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final notifications = context.watch<NotificationsProvider>();
    final pending = _stats?.reports.submitted ?? 0;

    return Scaffold(
      body: Column(
        children: [
          _OfficialHeader(user: user, unread: notifications.unread),
          // Gold gradient accent bar between header and content.
          Container(
            height: 3,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.accent,
                  AppColors.accentLight,
                  AppColors.accent,
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              backgroundColor: Colors.white,
              onRefresh: () async {
                final provider = context.read<NotificationsProvider>();
                await _load();
                await provider.load();
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.only(top: 6, bottom: 24),
                children: [
                  _WelcomeBanner(
                    firstName: user?.firstName.trim().isNotEmpty == true
                        ? user!.firstName.trim()
                        : 'there',
                    pending: pending,
                  ),
                  OfficialCard(
                    title: 'My Statistics',
                    contentPadding: EdgeInsets.zero,
                    child: _StatisticsRow(stats: _stats),
                  ),
                  OfficialCard(
                    title: 'Quick Services',
                    child: _ServicesGrid(role: user?.role ?? ''),
                  ),
                  OfficialCard(
                    title: 'Recent Projects',
                    actionLabel: 'View all →',
                    gradientHeader: true,
                    onAction: () => context.go('/projects'),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 10),
                    child: _RecentProjects(projects: _recentProjects),
                  ),
                  OfficialCard(
                    title: 'Recent Activity',
                    actionLabel: 'View all →',
                    gradientHeader: true,
                    onAction: () => Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (_) => const NotificationsScreen()),
                    ),
                    contentPadding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                    child: _ActivityLog(
                        items: notifications.items.take(5).toList()),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Official government header ─────────────────────────────────────────────

class _OfficialHeader extends StatelessWidget {
  final User? user;
  final int unread;
  const _OfficialHeader({required this.user, required this.unread});

  @override
  Widget build(BuildContext context) {
    final initials = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim()[0].toUpperCase())
        .join();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primaryDark,
            AppColors.primary,
            Color(0xFF007A3D),
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const FlagRibbon(),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const _TextLogo(),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Smart NGO M&E System',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.3,
                              ),
                        ),
                        Text(
                          'Monitoring & Evaluation Platform',
                          style: Theme.of(context)
                              .textTheme
                              .labelSmall
                              ?.copyWith(
                                color: Colors.white70,
                                fontSize: 10,
                                letterSpacing: 0.2,
                              ),
                        ),
                      ],
                    ),
                  ),
                  _BellButton(unread: unread),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => context.go('/profile'),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: Colors.white30, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          initials.isEmpty ? '?' : initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // User info bar with the gold separator into the content.
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF003D1F), AppColors.primaryDark],
                ),
                border: Border(
                  bottom: BorderSide(color: AppColors.accent, width: 2),
                ),
              ),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.person_outline,
                      color: Colors.white60, size: 14),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      user == null
                          ? '—'
                          : '${user!.fullName}  |  ${user!.roleLabel}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  const Text(
                    'Last login: Today',
                    style: TextStyle(color: Colors.white60, fontSize: 10),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// White square "NGO / M&E" text logo used in the official header.
class _TextLogo extends StatelessWidget {
  const _TextLogo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('NGO',
              style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                  height: 1.2)),
          Container(
            height: 2,
            width: 32,
            color: AppColors.accent,
            margin: const EdgeInsets.symmetric(vertical: 1),
          ),
          const Text('M&E',
              style: TextStyle(
                  color: AppColors.accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  height: 1.2)),
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
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_outlined,
              color: Colors.white, size: 24),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const NotificationsScreen()),
          ),
        ),
        if (unread > 0)
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              width: 16,
              height: 16,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: Color(0xFFCC0000),
                shape: BoxShape.circle,
              ),
              child: Text(
                unread > 9 ? '9+' : '$unread',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    height: 1),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Welcome banner ─────────────────────────────────────────────────────────

class _WelcomeBanner extends StatelessWidget {
  final String firstName;
  final int pending;
  const _WelcomeBanner({required this.firstName, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.waving_hand,
                color: AppColors.accentLight, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back, $firstName!',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'You have $pending pending '
                  'item${pending == 1 ? '' : 's'} requiring your attention.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios,
              color: Colors.white54, size: 16),
        ],
      ),
    );
  }
}

// ── Statistics ─────────────────────────────────────────────────────────────

class _StatisticsRow extends StatelessWidget {
  final DashboardStats? stats;
  const _StatisticsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    final s = stats;
    final totalReports = s == null
        ? null
        : s.reports.draft + s.reports.submitted + s.reports.approved;
    final items = [
      ('Projects', s?.projects.total, Icons.folder_open,
          AppColors.success, AppColors.successTint),
      ('Beneficiaries', s?.beneficiaries, Icons.people,
          AppColors.info, AppColors.infoTint),
      ('Reports', totalReports, Icons.description,
          AppColors.warning, AppColors.warningTint),
      ('Pending', s?.reports.submitted, Icons.pending_actions,
          AppColors.danger, AppColors.dangerTint),
    ];

    // Compact horizontal strip, eCitizen statistics-bar style.
    return Row(
      children: [
        for (final (i, item) in items.indexed) ...[
          if (i > 0)
            Container(width: 1, height: 60, color: AppColors.border),
          _ColoredStatBox(item: item),
        ],
      ],
    );
  }
}

class _ColoredStatBox extends StatelessWidget {
  final (String, int?, IconData, Color, Color) item;
  const _ColoredStatBox({required this.item});

  @override
  Widget build(BuildContext context) {
    final (label, value, icon, color, bgColor) = item;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
        color: bgColor,
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 4),
            if (value == null)
              Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                child: Container(width: 30, height: 22, color: Colors.white),
              )
            else
              Text(
                '$value',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: color.withValues(alpha: 0.8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick services grid ────────────────────────────────────────────────────

class _ServicesGrid extends StatelessWidget {
  final String role;
  const _ServicesGrid({required this.role});

  // Service tile accent colours.
  static const _green = AppColors.primary;
  static const _greenLight = Color(0xFF007A3D);
  static const _amber = AppColors.warning;
  static const _blue = AppColors.info;
  static const _purple = Color(0xFF5B2D8E);

  @override
  Widget build(BuildContext context) {
    final services = switch (role) {
      'officer' => [
          ('Submit Report', 'Field report', Icons.upload_file, _greenLight,
              () => _push(context, const SubmitReportScreen())),
          ('My Reports', 'View reports', Icons.description_outlined, _amber,
              () => context.go('/reports')),
          ('Beneficiaries', 'Register & manage', Icons.people_outline, _blue,
              () => context.go('/people')),
          ('My Projects', 'Assigned projects', Icons.folder_open, _green,
              () => context.go('/projects')),
          ('Add Beneficiary', 'New registration', Icons.person_add_outlined,
              _blue, () => _push(context, const RegisterBeneficiaryScreen())),
          ('Notifications', 'View alerts', Icons.notifications_outlined,
              _purple, () => _push(context, const NotificationsScreen())),
        ],
      'admin' => [
          ('Manage Users', 'User accounts', Icons.manage_accounts_outlined,
              _green, () => context.push('/users')),
          ('Manage NGOs', 'Organisations', Icons.domain_outlined, _blue,
              () => context.push('/ngos')),
          ('Projects', 'All projects', Icons.folder_open, _greenLight,
              () => context.go('/projects')),
          ('Reports', 'View & approve', Icons.description_outlined, _amber,
              () => context.go('/reports')),
          ('Analytics', 'View statistics', Icons.bar_chart_outlined, _purple,
              () => context.push('/analytics')),
          ('New Project', 'Create project', Icons.add_circle_outline, _green,
              () => context.push('/projects/new')),
        ],
      'donor' => [
          ('Projects', 'Funded projects', Icons.folder_open, _green,
              () => context.go('/projects')),
          ('Reports', 'Approved reports', Icons.description_outlined, _amber,
              () => context.go('/reports')),
          ('Analytics', 'View statistics', Icons.bar_chart_outlined, _purple,
              () => context.push('/analytics')),
          ('My Profile', 'Account details', Icons.person_outline, _blue,
              () => context.go('/profile')),
        ],
      // Manager default.
      _ => [
          ('Projects', 'Manage projects', Icons.folder_open, _green,
              () => context.go('/projects')),
          ('Reports', 'View & approve', Icons.description_outlined, _amber,
              () => context.go('/reports')),
          ('Beneficiaries', 'Register & manage', Icons.people_outline, _blue,
              () => context.go('/people')),
          ('New Project', 'Create project', Icons.add_circle_outline, _green,
              () => context.push('/projects/new')),
          ('Submit Report', 'Field report', Icons.upload_file, _greenLight,
              () => _push(context, const SubmitReportScreen())),
          ('Analytics', 'View statistics', Icons.bar_chart_outlined, _purple,
              () => context.push('/analytics')),
        ],
    };

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: 132,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: services.length,
      itemBuilder: (context, i) {
        final (label, subtitle, icon, color, onTap) = services[i];
        return _ServiceTile(
            label: label,
            subtitle: subtitle,
            icon: icon,
            color: color,
            onTap: onTap);
      },
    );
  }

  static void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ServiceTile extends StatelessWidget {
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(4),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [color, color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Icon(icon, color: Colors.white, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10, color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent projects (table-style rows) ─────────────────────────────────────

class _RecentProjects extends StatelessWidget {
  final List<Project>? projects;
  const _RecentProjects({required this.projects});

  @override
  Widget build(BuildContext context) {
    if (projects == null) {
      return Shimmer.fromColors(
        baseColor: Colors.grey[300]!,
        highlightColor: Colors.grey[100]!,
        child: Column(
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                height: 40,
                margin: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.white,
              ),
          ],
        ),
      );
    }
    if (projects!.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No projects on record.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
        ),
      );
    }
    return Column(
      children: [for (final p in projects!) _ProjectRow(project: p)],
    );
  }
}

class _ProjectRow extends StatelessWidget {
  final Project project;
  const _ProjectRow({required this.project});

  String get _endDate {
    final raw = project.endDate;
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('d MMM yyyy').format(parsed);
  }

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
    final accent = StatusBadge.accentFor(project.status);
    final progress = project.timelineProgress.clamp(0.0, 1.0);

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            projectId: project.id,
            title: project.projectName,
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
            bottom: const BorderSide(color: Color(0xFFEEEEEE)),
            right: BorderSide(
                color: accent.withValues(alpha: 0.3), width: 3),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.projectName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info, // official link colour
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 10, color: AppColors.textMuted),
                      const SizedBox(width: 3),
                      Text(
                        _endDate,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.attach_money,
                          size: 10, color: AppColors.textMuted),
                      Flexible(
                        child: Text(
                          _budget,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            StatusBadge(project.status),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${(progress * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 4),
                SizedBox(
                  width: 60,
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppColors.border,
                    valueColor: AlwaysStoppedAnimation(accent),
                    minHeight: 4,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent activity (official log style) ───────────────────────────────────

class _ActivityLog extends StatelessWidget {
  final List<AppNotification> items;
  const _ActivityLog({required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: Text('No recent activity.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppColors.textMuted)),
        ),
      );
    }
    return Column(
      children: [
        for (final (i, n) in items.indexed)
          _ActivityRow(notification: n, isLast: i == items.length - 1),
      ],
    );
  }
}

/// Timeline-style activity entry: coloured icon node with a connector line
/// down to the next entry, title + message, and a colour-matched timestamp.
class _ActivityRow extends StatelessWidget {
  final AppNotification notification;
  final bool isLast;
  const _ActivityRow({required this.notification, required this.isLast});

  (IconData, Color) get _spec {
    final text = '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) {
      return (Icons.check_circle_outline, AppColors.info);
    }
    if (text.contains('budget')) {
      return (Icons.account_balance_wallet_outlined, AppColors.danger);
    }
    if (text.contains('due') || text.contains('deadline')) {
      return (Icons.access_time_outlined, AppColors.warning);
    }
    if (text.contains('assign') || text.contains('added')) {
      return (Icons.person_add_outlined, AppColors.success);
    }
    if (text.contains('report')) {
      return (Icons.description_outlined, AppColors.success);
    }
    return (Icons.notifications_outlined, AppColors.neutral);
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
    final (icon, color) = _spec;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: const Color(0xFFEEEEEE),
                    margin: const EdgeInsets.symmetric(vertical: 3),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notification.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    notification.message,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
                  if (_timestamp.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      _timestamp,
                      style: TextStyle(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
