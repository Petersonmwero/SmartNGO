import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/info_chip.dart';
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

/// How far the cream content sheet rides up over the gradient header.
const double _kSheetOverlap = 28;

/// Role-aware home screen, styled like a premium fintech dashboard: a fixed
/// deep-gradient header (greeting, glowing avatar, glassy stats strip) with
/// the content sheet scrolling underneath its rounded top corners.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardStats? _stats;
  List<Project>? _recentProjects; // null while loading
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
    } catch (_) {
      // Show the empty state rather than a spinner forever.
      setState(() => _recentProjects ??= const []);
    }
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

    // Fixed header on top; the sheet below is stretched 28px taller than its
    // slot and pulled up by the same amount (via OverflowBox + translate), so
    // its rounded corners overlap the gradient with no gap at screen bottom.
    return Scaffold(
      body: Column(
        children: [
          _Header(
            user: user,
            unread: notifications.unread,
            stats: _stats,
            localDrafts: _localDrafts,
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => OverflowBox(
                alignment: Alignment.topCenter,
                minHeight: constraints.maxHeight + _kSheetOverlap,
                maxHeight: constraints.maxHeight + _kSheetOverlap,
                child: Transform.translate(
                  offset: const Offset(0, -_kSheetOverlap),
                  child: _buildSheet(user, notifications),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSheet(User? user, NotificationsProvider notifications) {
    final role = user?.role ?? '';
    final canCreate = role == 'manager' || role == 'admin';

    return ClipRRect(
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(28),
        topRight: Radius.circular(28),
      ),
      child: Container(
        color: AppColors.background,
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
            padding: const EdgeInsets.only(top: 12, bottom: 100),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: SectionHeader('Quick Actions'),
              ),
              _QuickActionsRow(role: role),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeader(
                  'Recent Projects',
                  actionLabel: 'See all',
                  onAction: () => context.go('/projects'),
                ),
              ),
              if (_recentProjects == null)
                const _ProjectsShimmer()
              else if (_recentProjects!.isEmpty)
                _EmptyProjectsCard(canCreate: canCreate)
              else
                for (final p in _recentProjects!)
                  _MiniProjectCard(project: p),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SectionHeader(
                  'Recent Activity',
                  actionLabel: 'See all',
                  onAction: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationsScreen()),
                  ),
                ),
              ),
              if (notifications.items.isEmpty)
                const _EmptyActivityCard()
              else
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      for (final (i, n)
                          in notifications.items.take(5).indexed) ...[
                        if (i > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 64),
                            child: Divider(
                                height: 1, color: Color(0xFFF3F4F6)),
                          ),
                        _ActivityItem(notification: n),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Fixed gradient header ──────────────────────────────────────────────────

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

  IconData get _roleIcon => switch (user?.role) {
        'admin' => Icons.admin_panel_settings_outlined,
        'manager' => Icons.workspace_premium_outlined,
        'officer' => Icons.badge_outlined,
        'donor' => Icons.volunteer_activism_outlined,
        _ => Icons.person_outline,
      };

  /// Role-aware trio shown in the stats strip.
  List<(String, String)> get _stripStats {
    final s = stats;
    final projects = s?.projects.total.toString() ?? '';
    final beneficiaries = s?.beneficiaries.toString() ?? '';
    final pending = s?.reports.submitted.toString() ?? '';
    final approved = s?.reports.approved.toString() ?? '';
    final totalReports = s == null
        ? ''
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
    final fullName = user?.fullName.trim().isNotEmpty == true
        ? user!.fullName.trim()
        : 'there';
    final initials = [user?.firstName, user?.lastName]
        .where((s) => s != null && s.trim().isNotEmpty)
        .map((s) => s!.trim()[0].toUpperCase())
        .join();

    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0A3D24), // deep forest
            AppColors.primary,
            AppColors.primaryMid,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: CustomPaint(
        painter: const _DotGridPainter(),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
              20, MediaQuery.paddingOf(context).top + 16, 20, 32),
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
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color:
                                    Colors.white.withValues(alpha: 0.65),
                                letterSpacing: 0.5,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$_greeting,',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.9),
                              ),
                        ),
                        Text(
                          '$fullName 👋',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                fontSize: 26,
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        if (user != null) _RoleBadge(_roleIcon, user!.roleLabel),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    children: [
                      _BellButton(unread: unread),
                      const SizedBox(height: 8),
                      if (initials.isNotEmpty) _GlowAvatar(initials),
                    ],
                  ),
                ],
              ),
              // Stats summary strip.
              Container(
                margin: const EdgeInsets.only(top: 20),
                padding: const EdgeInsets.symmetric(
                    vertical: 14, horizontal: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    for (final (i, item) in _stripStats.indexed) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.2),
                        ),
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (stats == null)
                              const _StatShimmer()
                            else
                              Text(
                                item.$1,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 24,
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            const SizedBox(height: 4),
                            Text(
                              item.$2,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                    fontSize: 11,
                                    color: Colors.white
                                        .withValues(alpha: 0.75),
                                  ),
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
        ),
      ),
    );
  }
}

/// Faint dot grid over the gradient — texture without distraction.
class _DotGridPainter extends CustomPainter {
  const _DotGridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.03);
    const spacing = 22.0;
    for (double y = 6; y < size.height; y += spacing) {
      for (double x = 6; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), 1.5, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Glassy pill with the role icon in amber.
class _RoleBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  const _RoleBadge(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.accentLight, size: 12),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
          ),
        ],
      ),
    );
  }
}

/// 52px amber-gradient avatar with a soft glow; taps through to Profile.
class _GlowAvatar extends StatelessWidget {
  final String initials;
  const _GlowAvatar(this.initials);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.go('/profile'),
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [AppColors.accent, AppColors.accentLight],
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.accent.withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            initials,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 18,
                  color: AppColors.charcoal,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
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
                width: 18,
                height: 18,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border:
                      Border.all(color: AppColors.primary, width: 1.5),
                ),
                child: Text(
                  unread > 9 ? '9+' : '$unread',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      height: 1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shimmering placeholder for a stats-strip number while stats load.
class _StatShimmer extends StatelessWidget {
  const _StatShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.25),
      highlightColor: Colors.white.withValues(alpha: 0.55),
      child: Container(
        width: 40,
        height: 24,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
  }
}

// ── Quick actions ──────────────────────────────────────────────────────────

enum _ChipStyle { primary, secondary }

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
          ('My Profile', Icons.person_outline, _ChipStyle.secondary,
              () => context.go('/profile')),
        ],
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (label, icon, style, onTap) in actions)
            _QuickActionChip(
                label: label, icon: icon, style: style, onTap: onTap),
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

/// Floating icon tile (green gradient = primary, amber tint = secondary)
/// with the label underneath — no card chrome around the pair.
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

  static const _amberTint = Color(0xFFFFF8E7);

  @override
  Widget build(BuildContext context) {
    final isPrimary = style == _ChipStyle.primary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 88,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                gradient: isPrimary
                    ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.primary, AppColors.primaryMid],
                      )
                    : null,
                color: isPrimary ? null : _amberTint,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: isPrimary
                        ? AppColors.primary.withValues(alpha: 0.25)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(icon,
                  color: isPrimary ? Colors.white : AppColors.accent,
                  size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.charcoal,
                    height: 1.3,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Recent projects ────────────────────────────────────────────────────────

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

  String get _endDate {
    final raw = project.endDate;
    if (raw == null) return '—';
    final parsed = DateTime.tryParse(raw);
    return parsed == null ? raw : DateFormat('d MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final accent = StatusBadge.accentFor(project.status);
    final progress = project.timelineProgress.clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
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
                  // Accent bar fading toward the bottom.
                  Container(
                    width: 5,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [accent, accent.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
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
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'Progress',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                        fontSize: 11,
                                        color: AppColors.muted),
                              ),
                              const Spacer(),
                              Text(
                                '${(progress * 100).round()}%',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(
                                      fontSize: 12,
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(999),
                            child: LinearProgressIndicator(
                              value: progress,
                              backgroundColor: const Color(0xFFE5E7EB),
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(accent),
                              minHeight: 5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              InfoChip(
                                  Icons.calendar_today_outlined, _endDate),
                              const SizedBox(width: 6),
                              InfoChip(Icons.payments_outlined, _budget),
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

/// Shimmer placeholders shown while the project list loads.
class _ProjectsShimmer extends StatelessWidget {
  const _ProjectsShimmer();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Column(
        children: [
          for (var i = 0; i < 3; i++)
            Container(
              height: 108,
              margin:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyProjectsCard extends StatelessWidget {
  final bool canCreate;
  const _EmptyProjectsCard({required this.canCreate});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.folder_open_outlined,
              size: 48, color: AppColors.muted),
          const SizedBox(height: 12),
          Text(
            'No projects yet',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            canCreate
                ? 'Create your first project to get started'
                : 'Projects you can access will appear here',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
          if (canCreate) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => context.push('/projects/new'),
              child: const Text('Create Project'),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Recent activity ────────────────────────────────────────────────────────

class _EmptyActivityCard extends StatelessWidget {
  const _EmptyActivityCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          'No recent activity.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(color: AppColors.muted),
        ),
      ),
    );
  }
}

class _ActivityItem extends StatelessWidget {
  final AppNotification notification;
  const _ActivityItem({required this.notification});

  /// Icon + color inferred from the notification's subject.
  (IconData, Color) get _iconSpec {
    final text = '${notification.title} ${notification.message}'.toLowerCase();
    if (text.contains('approv')) {
      return (Icons.check_circle_outline, AppColors.info);
    }
    if (text.contains('budget')) {
      return (Icons.account_balance_wallet_outlined, AppColors.danger);
    }
    if (text.contains('due') ||
        text.contains('deadline') ||
        text.contains('overdue')) {
      return (Icons.access_time_outlined, AppColors.accent);
    }
    if (text.contains('assign') || text.contains('added')) {
      return (Icons.person_add_outlined, AppColors.success);
    }
    if (text.contains('report')) {
      return (Icons.description_outlined, AppColors.success);
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
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
                        fontWeight: FontWeight.w600,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  notification.message,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (_timestamp.isNotEmpty)
            Text(
              _timestamp,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: AppColors.muted,
                  ),
            ),
        ],
      ),
    );
  }
}
