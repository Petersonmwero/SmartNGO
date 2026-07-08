import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../auth/auth_provider.dart';
import '../../reports/screens/submit_report_screen.dart';
import '../models/assignment.dart';
import '../models/indicator.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../project_repository.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.title,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectRepository _repo;
  late Future<Project> _project;
  late Future<List<Milestone>> _milestones;
  late Future<List<ProjectAssignment>> _team;
  late Future<List<Indicator>> _indicators;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ProjectRepository>();
    _project = _repo.get(widget.projectId);
    _milestones = _repo.milestones(widget.projectId);
    _team = _repo.assignments(widget.projectId);
    _indicators = _repo.indicators(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canReport =
        role == 'officer' || role == 'manager' || role == 'admin';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
          bottom: const TabBar(
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Milestones'),
              Tab(text: 'Team'),
              Tab(text: 'KPIs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(future: _project),
            _MilestonesTab(future: _milestones),
            _TeamTab(future: _team),
            _KpisTab(future: _indicators),
          ],
        ),
        floatingActionButton: canReport
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Report'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmitReportScreen(
                      projectId: widget.projectId,
                      projectName: widget.title,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

class _AsyncTab<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  const _AsyncTab({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.outlineVariant),
                const SizedBox(height: 12),
                Text('Failed to load',
                    style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          );
        }
        return builder(snapshot.data as T);
      },
    );
  }
}

// ── Overview ──────────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Future<Project> future;
  const _OverviewTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<Project>(
      future: future,
      builder: (p) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: Text(p.projectName,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
              const SizedBox(width: 8),
              _StatusChip(p),
            ],
          ),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(p.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted)),
          ],
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _DetailRow(label: 'Budget', value: p.budget),
                  const Divider(height: 24),
                  _DetailRow(label: 'Start date', value: p.startDate ?? '—'),
                  const Divider(height: 24),
                  _DetailRow(label: 'End date', value: p.endDate ?? '—'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final Project p;
  const _StatusChip(this.p);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: p.statusColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.statusColor.withValues(alpha: 0.5)),
      ),
      child: Text(
        p.statusLabel,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: p.statusColor,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(label,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: AppColors.muted)),
        ),
        Expanded(
          child: Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}

// ── Milestones ────────────────────────────────────────────────────────────────

class _MilestonesTab extends StatelessWidget {
  final Future<List<Milestone>> future;
  const _MilestonesTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<Milestone>>(
      future: future,
      builder: (items) => items.isEmpty
          ? _emptyState(context, Icons.flag_outlined, 'No milestones yet.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _MilestoneCard(items[i]),
            ),
    );
  }
}

class _MilestoneCard extends StatelessWidget {
  final Milestone m;
  const _MilestoneCard(this.m);

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (m.status) {
      'completed' => (Icons.check_circle, AppColors.statusActive),
      'overdue' => (Icons.warning_amber_rounded, AppColors.statusCancelled),
      _ => (Icons.radio_button_unchecked, AppColors.muted),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(m.title,
            style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('Due: ${m.dueDate ?? '—'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted)),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            m.status[0].toUpperCase() + m.status.substring(1),
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

// ── Team ──────────────────────────────────────────────────────────────────────

class _TeamTab extends StatelessWidget {
  final Future<List<ProjectAssignment>> future;
  const _TeamTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<ProjectAssignment>>(
      future: future,
      builder: (items) => items.isEmpty
          ? _emptyState(context, Icons.group_outlined, 'No team members assigned.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _TeamCard(items[i]),
            ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final ProjectAssignment a;
  const _TeamCard(this.a);

  @override
  Widget build(BuildContext context) {
    final initial = a.userName.isNotEmpty ? a.userName[0].toUpperCase() : '?';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withValues(alpha: 0.12),
          child: Text(initial,
              style: const TextStyle(
                  color: AppColors.primary, fontWeight: FontWeight.w700)),
        ),
        title: Text(a.userName,
            style: Theme.of(context).textTheme.titleSmall),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            a.role[0].toUpperCase() + a.role.substring(1),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppColors.statusActive,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────────

class _KpisTab extends StatelessWidget {
  final Future<List<Indicator>> future;
  const _KpisTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<Indicator>>(
      future: future,
      builder: (items) => items.isEmpty
          ? _emptyState(context, Icons.bar_chart, 'No indicators defined.')
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _KpiCard(items[i]),
            ),
    );
  }
}

class _KpiCard extends StatelessWidget {
  final Indicator ind;
  const _KpiCard(this.ind);

  @override
  Widget build(BuildContext context) {
    final pct = ind.progressPercent;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ind.indicatorName,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ind.fraction,
                minHeight: 8,
                backgroundColor: AppColors.border,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ind.currentValue} / ${ind.targetValue}${ind.unit.isNotEmpty ? ' ${ind.unit}' : ''}',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                ),
                if (pct != null)
                  Text(
                    '${pct.toStringAsFixed(1)}%',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
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

// ── Shared helpers ────────────────────────────────────────────────────────────

Widget _emptyState(BuildContext context, IconData icon, String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 52, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
