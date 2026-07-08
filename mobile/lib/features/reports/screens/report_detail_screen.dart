import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
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
                  const Icon(Icons.error_outline, size: 48, color: AppColors.muted),
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

  @override
  Widget build(BuildContext context) {
    final role = context.read<AuthProvider>().user?.role ?? '';
    final canApprove =
        (role == 'admin' || role == 'manager') && report.status == 'submitted';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Status + type row
        Row(
          children: [
            _StatusChip(report.status),
            const SizedBox(width: 8),
            Chip(
              label: Text(report.typeLabel),
              visualDensity: VisualDensity.compact,
              backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
              labelStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(report.title, style: Theme.of(context).textTheme.headlineSmall),
        if (report.dateSubmitted != null) ...[
          const SizedBox(height: 4),
          Text(
            'Submitted: ${report.dateSubmitted!.substring(0, 10)}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted),
          ),
        ],
        const SizedBox(height: 16),

        // Description
        if (report.description.isNotEmpty) ...[
          Text('Description', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Text(report.description, style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 16),
        ],

        // GPS location
        if (report.gpsLatitude != null && report.gpsLongitude != null) ...[
          Text('Location', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${report.gpsLatitude!.toStringAsFixed(6)}, '
                      '${report.gpsLongitude!.toStringAsFixed(6)}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
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
              itemBuilder: (context, i) {
                final img = report.images[i];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    img.imageUrl,
                    width: 140,
                    height: 140,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      width: 140,
                      height: 140,
                      color: AppColors.border,
                      child: const Icon(Icons.broken_image_outlined,
                          color: AppColors.muted),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // Approve button — manager/admin only, when submitted
        if (canApprove)
          _ApproveButton(reportId: report.id, onApproved: onApproved),
      ],
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip(this.status);

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'approved' => AppColors.statusActive,
      'submitted' => AppColors.statusCompleted,
      _ => AppColors.muted,
    };
    final label = switch (status) {
      'approved' => 'Approved',
      'submitted' => 'Submitted',
      _ => 'Draft',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
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
    setState(() => _loading = true);
    try {
      await context.read<ReportRepository>().approve(widget.reportId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report approved successfully.')),
      );
      widget.onApproved();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to approve: $e')),
      );
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
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.white))
          : const Icon(Icons.check_circle_outline),
      label: const Text('Approve Report'),
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.statusActive,
      ),
    );
  }
}
