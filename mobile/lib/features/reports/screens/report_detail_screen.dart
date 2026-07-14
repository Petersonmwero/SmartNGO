import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
import '../models/report.dart';
import '../report_repository.dart';

/// Full report detail: title, GPS, description, photo gallery, approve action.
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
          ],
        ),
        const SizedBox(height: 20),

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

  Future<void> _openMaps(double lat, double lng) async {
    final uri = Uri.parse('https://www.google.com/maps?q=$lat,$lng');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
