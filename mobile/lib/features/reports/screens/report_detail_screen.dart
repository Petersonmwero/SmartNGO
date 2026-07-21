import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
import '../../projects/widgets/evm_cards.dart' show formatKes;
import '../models/activity_type.dart';
import '../models/report.dart';
import '../report_repository.dart';

/// Full report detail: title, structured results (spend and reach), impact
/// narrative, GPS, description, photo gallery, and the approve action.
class ReportDetailScreen extends StatefulWidget {
  final int reportId;
  const ReportDetailScreen({super.key, required this.reportId});

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late Future<Report> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<ReportRepository>();
    _future = repo.get(widget.reportId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Detail')),
      body: FutureBuilder<Report>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  Text('Failed to load report.',
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          final report = snap.data!;
          return _ReportBody(report: report, onApproved: () => setState(_load));
        },
      ),
    );
  }
}

class _ReportBody extends StatelessWidget {
  final Report report;
  final VoidCallback onApproved;
  const _ReportBody({required this.report, required this.onApproved});

  /// Full-width banner reflecting the workflow state.
  Widget _statusBanner(BuildContext context) {
    final (label, icon, fg, bg) = switch (report.status) {
      'approved' => (
          'Approved',
          Icons.check_circle_outline,
          AppColors.success,
          AppColors.successTint
        ),
      'submitted' => (
          'Awaiting Approval',
          Icons.hourglass_top_outlined,
          AppColors.warning,
          AppColors.warningTint
        ),
      _ => ('Draft', Icons.edit_note_outlined, AppColors.neutral,
          AppColors.neutralTint),
    };
    return Container(
      width: double.infinity,
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: fg,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role ?? '';
    final canApprove =
        (role == 'admin' || role == 'manager') && report.status == 'submitted';

    return Column(
      children: [
        _statusBanner(context),
        Expanded(
          child: _buildContent(context, canApprove),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context, bool canApprove) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(report.title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            StatusBadge(report.status),
            InfoChip(Icons.assignment_outlined, report.typeLabel),
            if (report.officerName != null && report.officerName!.isNotEmpty)
              InfoChip(Icons.person_outline, report.officerName!),
            if (report.dateSubmitted != null)
              InfoChip(Icons.access_time,
                  report.dateSubmitted!.substring(0, 10)),
            if (report.activityType.isNotEmpty)
              InfoChip(Icons.category_outlined,
                  ReportActivityType.labelFor(report.activityType)),
          ],
        ),
        const SizedBox(height: 20),

        // Structured donor reporting: what it cost and who it reached.
        if (report.amountSpent > 0 || report.beneficiariesReached > 0) ...[
          Text('Results Recorded',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (report.amountSpent > 0) ...[
                    _MetricRow(
                      icon: Icons.payments_outlined,
                      label: 'Amount spent',
                      value: formatKes(report.amountSpent),
                      // Until a manager approves, nothing has posted to the
                      // project ledger — say so rather than imply it counted.
                      note: report.postedAt == null
                          ? 'Counts towards the project budget once approved'
                          : null,
                    ),
                    if (report.expenditureNotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6, left: 34),
                        child: Text(report.expenditureNotes,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.textSecondary)),
                      ),
                  ],
                  if (report.amountSpent > 0 &&
                      report.beneficiariesReached > 0)
                    const Divider(height: 22),
                  if (report.beneficiariesReached > 0)
                    _MetricRow(
                      icon: Icons.groups_outlined,
                      label: 'People reached',
                      value: '${report.beneficiariesReached}',
                      note: _reachBreakdown(report),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        if (report.hasNarrative) ...[
          Text('Impact & Learning',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _narrative(context, 'Impact observed',
                      report.impactDescription, Icons.trending_up),
                  _narrative(context, 'Challenges faced',
                      report.challengesFaced, Icons.warning_amber_outlined),
                  _narrative(context, 'Recommendations',
                      report.recommendations, Icons.lightbulb_outline),
                  _narrative(context, 'Next steps', report.nextSteps,
                      Icons.arrow_forward),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // GPS location
        if (report.gpsLatitude != null && report.gpsLongitude != null) ...[
          Text('Location', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_outlined,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${report.gpsLatitude!.toStringAsFixed(6)}, '
                      '${report.gpsLongitude!.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  TextButton(
                    onPressed: () => _openMaps(
                        report.gpsLatitude!, report.gpsLongitude!),
                    child: const Text('View on Maps'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Photo gallery
        if (report.images.isNotEmpty) ...[
          Text('Photos (${report.images.length})',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SizedBox(
            height: 140,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: report.images.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => _PhotoThumb(
                image: report.images[i],
                index: i,
                total: report.images.length,
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Description
        if (report.description.isNotEmpty) ...[
          Text('Activity Description',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(report.description,
                  style: Theme.of(context).textTheme.bodyMedium),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Approve button — manager/admin only, when submitted
        if (canApprove)
          _ApproveButton(reportId: report.id, onApproved: onApproved),
      ],
    );
  }

  /// "140 male · 160 female · 90 youth" — only the parts recorded.
  static String? _reachBreakdown(Report report) {
    final parts = <String>[
      if (report.beneficiariesMale > 0) '${report.beneficiariesMale} male',
      if (report.beneficiariesFemale > 0)
        '${report.beneficiariesFemale} female',
      if (report.beneficiariesYouth > 0) '${report.beneficiariesYouth} youth',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  Widget _narrative(
      BuildContext context, String label, String body, IconData icon) {
    if (body.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: AppColors.primary),
              const SizedBox(width: 6),
              Text(label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: AppColors.primary,
                  )),
            ],
          ),
          const SizedBox(height: 4),
          Text(body, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// Icon + label + figure, with an optional muted note underneath.
class _MetricRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? note;

  const _MetricRow({
    required this.icon,
    required this.label,
    required this.value,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.textSecondary)),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 28),
            child: Text(note!,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.textMuted)),
          ),
      ],
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final ReportImage image;
  final int index;
  final int total;

  const _PhotoThumb(
      {required this.image, required this.index, required this.total});

  void _openFullScreen(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  image.imageUrl,
                  errorBuilder: (_, _, _) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64),
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: Text(
                '${index + 1} of $total',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _openFullScreen(context),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.network(
          image.imageUrl,
          width: 140,
          height: 140,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            width: 140,
            height: 140,
            color: AppColors.border,
            child:
                const Icon(Icons.broken_image_outlined, color: AppColors.muted),
          ),
        ),
      ),
    );
  }
}

class _ApproveButton extends StatefulWidget {
  final int reportId;
  final VoidCallback onApproved;
  const _ApproveButton({required this.reportId, required this.onApproved});

  @override
  State<_ApproveButton> createState() => _ApproveButtonState();
}

class _ApproveButtonState extends State<_ApproveButton> {
  bool _loading = false;

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Approve report'),
        content: const Text(
            'Approve this report? Approved reports become read-only and '
            'are included in donor summaries.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Approve'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _loading = true);
    try {
      await context.read<ReportRepository>().approve(widget.reportId);
      if (!mounted) return;
      showSuccessSnackBar(context, 'Report approved successfully!');
      widget.onApproved();
    } catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, 'Failed to approve: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      onPressed: _loading ? null : _approve,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child:
                  CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check_circle_outline),
      label: const Text('Approve Report'),
    );
  }
}
