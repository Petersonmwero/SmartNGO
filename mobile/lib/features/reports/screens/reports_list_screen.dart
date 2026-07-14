import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/status_badge.dart';
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
  int? _count;

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
    _future = repo.list(status: _status).then((p) {
      if (mounted) setState(() => _count = p.count);
      return p.results;
    });
    _draftsFuture = context.read<DraftStore>().list();
  }

  Future<void> _openDraft(ReportDraft draft) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => SubmitReportScreen(draft: draft)),
    );
    if (changed == true && mounted) setState(_load);
  }

  Future<void> _deleteDraft(ReportDraft draft) async {
    await context.read<DraftStore>().delete(draft.id!);
    if (mounted) setState(_load);
  }

  Future<void> _newReport() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const SubmitReportScreen()),
    );
    if (changed == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reports'),
            if (_count != null)
              Text(
                '$_count report${_count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Submit report',
        onPressed: _newReport,
        child: const Icon(Icons.add),
      ),
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
                    return const ShimmerList();
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
                        return EmptyState(
                          Icons.cloud_off_outlined,
                          'Something went wrong',
                          errorMsg,
                          buttonLabel: 'Retry',
                          onButton: () => setState(_load),
                        );
                      }
                      if (items.isEmpty && drafts.isEmpty && errorMsg == null) {
                        return EmptyState(
                          Icons.description_outlined,
                          'No reports',
                          'Field reports you can access will appear here.',
                          buttonLabel: 'Submit Report',
                          onButton: _newReport,
                        );
                      }
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                        children: [
                          if (drafts.isNotEmpty) ...[
                            const SectionHeader('On This Device',
                                color: AppColors.warning),
                            for (final draft in drafts)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Dismissible(
                                  key: ValueKey('draft-${draft.id}'),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.danger,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(Icons.delete_outline,
                                        color: Colors.white),
                                  ),
                                  onDismissed: (_) => _deleteDraft(draft),
                                  child: _DraftCard(
                                    draft: draft,
                                    onOpen: () => _openDraft(draft),
                                  ),
                                ),
                              ),
                          ],
                          if (errorMsg != null)
                            _InlineError(errorMsg,
                                onRetry: () => setState(_load))
                          else ...[
                            if (drafts.isNotEmpty && items.isNotEmpty)
                              const SectionHeader('Submitted Reports'),
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

/// Card for a report draft saved locally with sqflite; tap to resume it in
/// the Submit Report form, swipe left to delete.
class _DraftCard extends StatelessWidget {
  final ReportDraft draft;
  final VoidCallback onOpen;

  const _DraftCard({required this.draft, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Amber accent bar marks device-local drafts.
              Container(width: 4, color: AppColors.accent),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              draft.title.isEmpty
                                  ? '(Untitled draft)'
                                  : draft.title,
                              style: Theme.of(context).textTheme.titleMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const StatusBadge('submitted', label: 'Local Draft'),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          InfoChip(Icons.work_outline, draft.projectName),
                          InfoChip(
                              Icons.edit_outlined,
                              'edited ${draft.updatedAt.toString().substring(0, 10)}'),
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
    final (accent, _) = StatusBadge.colorsFor(report.status);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/reports/${report.id}'),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(width: 4, color: accent),
              Expanded(
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
                          StatusBadge(report.status),
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
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          InfoChip(
                              Icons.assignment_outlined, report.typeLabel),
                          if (report.officerName != null &&
                              report.officerName!.isNotEmpty)
                            InfoChip(
                                Icons.person_outline, report.officerName!),
                          if (report.dateSubmitted != null)
                            InfoChip(
                              Icons.access_time,
                              report.dateSubmitted!.length >= 10
                                  ? report.dateSubmitted!.substring(0, 10)
                                  : report.dateSubmitted!,
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
    );
  }
}
