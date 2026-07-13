import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../draft_store.dart';
import '../models/report.dart';
import '../models/report_draft.dart';
import '../report_repository.dart';
import 'submit_report_screen.dart';

class ReportsListScreen extends StatefulWidget {
  const ReportsListScreen({super.key});

  @override
  State<ReportsListScreen> createState() => _ReportsListScreenState();
}

class _ReportsListScreenState extends State<ReportsListScreen> {
  late Future<List<Report>> _future;
  late Future<List<ReportDraft>> _draftsFuture;
  String? _status;

  static const _statuses = <String?, String>{
    null: 'All',
    'draft': 'Drafts',
    'submitted': 'Submitted',
    'approved': 'Approved',
  };

  /// Local device drafts are shown under the All and Drafts filters.
  bool get _showDrafts => _status == null || _status == 'draft';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<ReportRepository>();
    _future = repo.list(status: _status).then((p) => p.results);
    _draftsFuture = context.read<DraftStore>().list();
  }

  Future<void> _openDraft(ReportDraft draft) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SubmitReportScreen(
          projectId: draft.projectId,
          projectName: draft.projectName,
          draft: draft,
        ),
      ),
    );
    if (changed == true && mounted) setState(_load);
  }

  Future<void> _deleteDraft(ReportDraft draft) async {
    await context.read<DraftStore>().delete(draft.id!);
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: Column(
        children: [
          _FilterBar(
            current: _status,
            statuses: _statuses,
            onSelect: (v) => setState(() {
              _status = v;
              _load();
            }),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: FutureBuilder<List<Report>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return _ShimmerList();
                  }
                  final err = snapshot.error;
                  final errorMsg = snapshot.hasError
                      ? (err is ApiException ? err.message : 'Failed to load.')
                      : null;
                  final items = snapshot.data ?? [];
                  return FutureBuilder<List<ReportDraft>>(
                    future: _draftsFuture,
                    builder: (context, draftSnapshot) {
                      final drafts = _showDrafts
                          ? (draftSnapshot.data ?? const <ReportDraft>[])
                          : const <ReportDraft>[];
                      // Local drafts stay visible even when the server list
                      // fails — the officer may simply be offline.
                      if (errorMsg != null && drafts.isEmpty) {
                        return _Empty(errorMsg,
                            onRetry: () => setState(_load));
                      }
                      if (items.isEmpty && drafts.isEmpty && errorMsg == null) {
                        return const _Empty('No reports found.');
                      }
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          if (drafts.isNotEmpty) ...[
                            const _SectionHeader('On this device'),
                            for (final draft in drafts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DraftCard(
                                  draft: draft,
                                  onOpen: () => _openDraft(draft),
                                  onDelete: () => _deleteDraft(draft),
                                ),
                              ),
                          ],
                          if (errorMsg != null)
                            _InlineError(errorMsg,
                                onRetry: () => setState(_load))
                          else ...[
                            if (drafts.isNotEmpty && items.isNotEmpty)
                              const _SectionHeader('On the server'),
                            for (final report in items)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _ReportCard(report: report),
                              ),
                          ],
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final String? current;
  final Map<String?, String> statuses;
  final ValueChanged<String?> onSelect;

  const _FilterBar({
    required this.current,
    required this.statuses,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final entry in statuses.entries)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(entry.value),
                selected: current == entry.key,
                onSelected: (_) => onSelect(entry.key),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: current == entry.key ? Colors.white : null,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.muted,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

/// Card for a report draft saved locally with sqflite; tap to resume it in
/// the Submit Report form.
class _DraftCard extends StatelessWidget {
  final ReportDraft draft;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            draft.title,
                            style: Theme.of(context).textTheme.titleMedium,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        const _Badge(
                            label: 'Local draft', color: AppColors.accent),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${draft.projectName} · edited '
                      '${draft.updatedAt.toString().substring(0, 10)}',
                      style: Theme.of(context)
                          .textTheme
                          .labelSmall
                          ?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, size: 20),
                color: AppColors.muted,
                tooltip: 'Delete draft',
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact error row shown below local drafts when the server list fails,
/// so being offline never hides the device's own drafts.
class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _InlineError(this.message, {required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.cloud_off_outlined, color: AppColors.muted),
        title: Text(message, style: Theme.of(context).textTheme.bodyMedium),
        trailing: TextButton(onPressed: onRetry, child: const Text('Retry')),
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final Report report;
  const _ReportCard({required this.report});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(report.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => context.push('/reports/${report.id}'),
        child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    report.title,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _Badge(label: report.statusLabel, color: statusColor),
              ],
            ),
            if (report.description.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                report.description,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.assignment_outlined,
                    size: 13, color: AppColors.muted),
                const SizedBox(width: 4),
                Text(
                  report.typeLabel,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (report.dateSubmitted != null) ...[
                  const SizedBox(width: 12),
                  const Icon(Icons.access_time,
                      size: 13, color: AppColors.muted),
                  const SizedBox(width: 4),
                  Text(
                    report.dateSubmitted!.length >= 10
                        ? report.dateSubmitted!.substring(0, 10)
                        : report.dateSubmitted!,
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'approved':
        return AppColors.statusActive;
      case 'submitted':
        return AppColors.statusCompleted;
      default:
        return AppColors.muted;
    }
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: 6,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (_, _) => Container(
          height: 96,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5)),
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

class _Empty extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _Empty(this.message, {this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.description_outlined,
            size: 52,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          const SizedBox(height: 12),
          Text(message, style: Theme.of(context).textTheme.bodyMedium),
          if (onRetry != null) ...[
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ],
      ),
    );
  }
}
