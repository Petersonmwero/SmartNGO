import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/project_progress_bar.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../../reports/screens/submit_report_screen.dart';
import '../../users/user_repository.dart';
import '../models/assignment.dart';
import '../models/indicator.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../project_repository.dart';
import '../widgets/evm_cards.dart';
import 'create_project_screen.dart';
import 'phase_management_screen.dart';

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

class _ProjectDetailScreenState extends State<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late final ProjectRepository _repo;
  late final TabController _tabs;
  late Future<Project> _project;
  late Future<List<Milestone>> _milestones;
  late Future<List<ProjectAssignment>> _team;
  late Future<List<Indicator>> _indicators;
  late Future<int> _beneficiaryCount;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ProjectRepository>();
    _tabs = TabController(length: 4, vsync: this);
    _tabs.addListener(() {
      // Rebuild so the FAB matches the active tab.
      if (!_tabs.indexIsChanging) setState(() {});
    });
    _loadAll();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _loadAll() {
    _project = _repo.get(widget.projectId);
    _milestones = _repo.milestones(widget.projectId);
    _team = _repo.assignments(widget.projectId);
    _indicators = _repo.indicators(widget.projectId);
    _beneficiaryCount =
        context.read<BeneficiaryRepository>().count(projectId: widget.projectId);
  }

  void _reload() => setState(_loadAll);

  Future<void> _openSubmitReport() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SubmitReportScreen(
          projectId: widget.projectId,
          projectName: widget.title,
        ),
      ),
    );
  }

  Future<void> _addMilestone() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddMilestoneSheet(projectId: widget.projectId),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _addIndicator() async {
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddIndicatorSheet(projectId: widget.projectId),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _assignOfficer() async {
    final team = await _team;
    if (!mounted) return;
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignOfficerSheet(
        projectId: widget.projectId,
        alreadyAssigned: team.map((a) => a.user).toSet(),
      ),
    );
    if (added == true && mounted) _reload();
  }

  Future<void> _openPhaseManagement() async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PhaseManagementScreen(
          projectId: widget.projectId,
          projectName: widget.title,
        ),
      ),
    );
    // Phase spend feeds the server-computed progress — refetch on change.
    if (changed == true && mounted) _reload();
  }

  Future<void> _editProject() async {
    final project = await _project;
    if (!mounted) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CreateProjectScreen(project: project)),
    );
    if (changed == true && mounted) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canReport = role == 'officer' || role == 'manager' || role == 'admin';
    final canManage = role == 'manager' || role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(96),
          child: Column(
            children: [
              FutureBuilder<Project>(
                future: _project,
                builder: (context, snap) {
                  final p = snap.data;
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Row(
                      children: [
                        if (p != null) ...[
                          StatusBadge(p.status),
                          const SizedBox(width: 8),
                          _HeaderBadge(_formatBudget(p.budget)),
                          const SizedBox(width: 8),
                          _HeaderBadge(
                              '${p.progressPercentage.round()}% complete'),
                        ],
                      ],
                    ),
                  );
                },
              ),
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabs,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: const [
                    Tab(text: 'Overview'),
                    Tab(text: 'Milestones'),
                    Tab(text: 'Team'),
                    Tab(text: 'KPIs'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _OverviewTab(
            future: _project,
            milestones: _milestones,
            beneficiaryCount: _beneficiaryCount,
            canManage: canManage,
            onEdit: _editProject,
            onManagePhases: _openPhaseManagement,
          ),
          _MilestonesTab(future: _milestones),
          _TeamTab(
            future: _team,
            canManage: canManage,
            projectId: widget.projectId,
            onChanged: _reload,
            onAssign: _assignOfficer,
          ),
          _KpisTab(future: _indicators),
        ],
      ),
      floatingActionButton: switch (_tabs.index) {
        0 when canReport => FloatingActionButton.extended(
            icon: const Icon(Icons.add),
            label: const Text('Report'),
            onPressed: _openSubmitReport,
          ),
        1 when canManage => FloatingActionButton.extended(
            icon: const Icon(Icons.flag_outlined),
            label: const Text('Add Milestone'),
            onPressed: _addMilestone,
          ),
        3 when canManage => FloatingActionButton.extended(
            icon: const Icon(Icons.bar_chart_outlined),
            label: const Text('Add Indicator'),
            onPressed: _addIndicator,
          ),
        _ => null,
      },
    );
  }
}

String _formatBudget(String raw) {
  final value = double.tryParse(raw);
  if (value == null) return 'KES $raw';
  if (value >= 1000000) return 'KES ${(value / 1000000).toStringAsFixed(1)}M';
  if (value >= 1000) return 'KES ${(value / 1000).toStringAsFixed(0)}K';
  return 'KES ${value.toStringAsFixed(0)}';
}

class _HeaderBadge extends StatelessWidget {
  final String label;
  const _HeaderBadge(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: Colors.white, fontWeight: FontWeight.w600),
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

// ── Overview ──────────────────────────────────────────────────────────────

class _OverviewTab extends StatelessWidget {
  final Future<Project> future;
  final Future<List<Milestone>> milestones;
  final Future<int> beneficiaryCount;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onManagePhases;

  const _OverviewTab({
    required this.future,
    required this.milestones,
    required this.beneficiaryCount,
    required this.canManage,
    required this.onEdit,
    required this.onManagePhases,
  });

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<Project>(
      future: future,
      builder: (p) => ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        children: [
          // 2×2 info grid.
          Row(
            children: [
              Expanded(
                  child: _InfoCell(
                      'Start Date', p.startDate ?? '—', Icons.calendar_today_outlined)),
              const SizedBox(width: 12),
              Expanded(
                  child:
                      _InfoCell('End Date', p.endDate ?? '—', Icons.event_outlined)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                  child: _InfoCell(
                      'Budget', _formatBudget(p.budget), Icons.payments_outlined)),
              const SizedBox(width: 12),
              Expanded(
                child: FutureBuilder<int>(
                  future: beneficiaryCount,
                  builder: (context, snap) => _InfoCell(
                    'Beneficiaries',
                    snap.hasData ? '${snap.data}' : '—',
                    Icons.people_outline,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Weighted Composite Progress (EVM) — computed server-side.
          FutureBuilder<List<Milestone>>(
            future: milestones,
            builder: (context, snap) =>
                ProjectProgressCard(project: p, milestones: snap.data),
          ),
          const SizedBox(height: 12),
          ProjectHealthCard(project: p),
          const SizedBox(height: 12),
          PhaseBudgetTable(
            project: p,
            canManage: canManage,
            onManage: onManagePhases,
          ),
          if (p.description.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Description', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Text(p.description,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppColors.muted)),
          ],
          if (canManage) ...[
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: const Text('Edit Project'),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCell extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _InfoCell(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700)),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelSmall
                    ?.copyWith(color: AppColors.muted)),
          ],
        ),
      ),
    );
  }
}

// ── Milestones ────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
      'completed' => (Icons.check_circle, AppColors.success),
      'overdue' => (Icons.warning_amber_rounded, AppColors.danger),
      _ => (Icons.hourglass_empty, AppColors.muted),
    };

    return Card(
      child: ListTile(
        leading: Icon(icon, color: color),
        title: Text(m.title, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Text('Due: ${m.dueDate ?? '—'} · Weight ${m.weight}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.muted)),
        trailing: StatusBadge(m.status),
      ),
    );
  }
}

// ── Team ──────────────────────────────────────────────────────────────────

class _TeamTab extends StatelessWidget {
  final Future<List<ProjectAssignment>> future;
  final bool canManage;
  final int projectId;
  final VoidCallback onChanged;
  final VoidCallback onAssign;

  const _TeamTab({
    required this.future,
    required this.canManage,
    required this.projectId,
    required this.onChanged,
    required this.onAssign,
  });

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<ProjectAssignment>>(
      future: future,
      builder: (items) => Column(
        children: [
          Expanded(
            child: items.isEmpty
                ? _emptyState(
                    context, Icons.group_outlined, 'No team members assigned.')
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _TeamCard(
                      items[i],
                      canManage: canManage,
                      projectId: projectId,
                      onRemoved: onChanged,
                    ),
                  ),
          ),
          if (canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAssign,
                  icon: const Icon(Icons.person_add_outlined, size: 18),
                  label: const Text('Assign Officer'),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TeamCard extends StatelessWidget {
  final ProjectAssignment a;
  final bool canManage;
  final int projectId;
  final VoidCallback onRemoved;

  const _TeamCard(
    this.a, {
    required this.canManage,
    required this.projectId,
    required this.onRemoved,
  });

  Future<void> _remove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove team member'),
        content: Text('Remove ${a.userName} from this project? '
            'Their submitted reports are preserved.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      await context
          .read<ProjectRepository>()
          .removeAssignment(projectId, a.user);
      onRemoved();
    } on ApiException catch (e) {
      if (context.mounted) {
        showErrorSnackBar(context, e.message);
      }
    }
  }

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
        title: Row(
          children: [
            Flexible(
              child: Text(a.userName,
                  style: Theme.of(context).textTheme.titleSmall,
                  overflow: TextOverflow.ellipsis),
            ),
            if (a.role == 'manager') ...[
              const SizedBox(width: 6),
              const Icon(Icons.star, size: 14, color: AppColors.accent),
            ],
          ],
        ),
        subtitle: StatusBadge(
          a.role == 'manager' ? 'active' : 'completed',
          label: a.role == 'manager' ? 'Manager' : 'Officer',
        ),
        trailing: canManage
            ? IconButton(
                tooltip: 'Remove from project',
                icon: const Icon(Icons.person_remove_outlined,
                    size: 20, color: AppColors.muted),
                onPressed: () => _remove(context),
              )
            : null,
      ),
    );
  }
}

// ── KPIs ──────────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(ind.indicatorName,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            ProjectProgressBar(
              ind.fraction,
              label:
                  '${ind.currentValue} / ${ind.targetValue}${ind.unit.isNotEmpty ? ' ${ind.unit}' : ''}',
            ),
          ],
        ),
      ),
    );
  }
}

// ── Bottom sheets ─────────────────────────────────────────────────────────

class _AddMilestoneSheet extends StatefulWidget {
  final int projectId;
  const _AddMilestoneSheet({required this.projectId});

  @override
  State<_AddMilestoneSheet> createState() => _AddMilestoneSheetState();
}

class _AddMilestoneSheetState extends State<_AddMilestoneSheet> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  DateTime? _dueDate;
  int _weight = 1;
  bool _busy = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ProjectRepository>().createMilestone(
            widget.projectId,
            title: _title.text.trim(),
            dueDate: DateFormat('yyyy-MM-dd').format(_dueDate!),
            weight: _weight,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Milestone',
      busy: _busy,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            // Weight drives the physical-progress dimension of the
            // composite progress model (1 = minor, 10 = critical).
            DropdownButtonFormField<int>(
              initialValue: _weight,
              decoration: const InputDecoration(
                labelText: 'Weight (importance)',
                helperText: 'Counts towards physical progress',
              ),
              items: [
                for (var w = 1; w <= 10; w++)
                  DropdownMenuItem(
                    value: w,
                    child: Text(switch (w) {
                      1 => '1 — Minor',
                      5 => '5 — Major',
                      10 => '10 — Critical',
                      _ => '$w',
                    }),
                  ),
              ],
              onChanged: (v) => setState(() => _weight = v!),
            ),
            const SizedBox(height: 12),
            FormField<DateTime>(
              validator: (_) => _dueDate == null ? 'Pick a due date' : null,
              builder: (state) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.event_outlined, size: 18),
                    label: Text(_dueDate != null
                        ? DateFormat('yyyy-MM-dd').format(_dueDate!)
                        : 'Due Date'),
                    onPressed: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) setState(() => _dueDate = picked);
                    },
                  ),
                  if (state.errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, top: 4),
                      child: Text(state.errorText!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                              fontSize: 12)),
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

class _AddIndicatorSheet extends StatefulWidget {
  final int projectId;
  const _AddIndicatorSheet({required this.projectId});

  @override
  State<_AddIndicatorSheet> createState() => _AddIndicatorSheetState();
}

class _AddIndicatorSheetState extends State<_AddIndicatorSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _unit = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _unit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<ProjectRepository>().createIndicator(
            widget.projectId,
            name: _name.text.trim(),
            targetValue: double.parse(_target.text.trim()),
            unit: _unit.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SheetScaffold(
      title: 'Add Indicator',
      busy: _busy,
      onSave: _save,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Indicator name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _target,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Target value'),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (double.tryParse(v.trim()) == null) {
                  return 'Enter a valid number';
                }
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _unit,
              decoration: const InputDecoration(
                  labelText: 'Unit (optional)', hintText: 'e.g. wells'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignOfficerSheet extends StatefulWidget {
  final int projectId;
  final Set<int> alreadyAssigned;
  const _AssignOfficerSheet(
      {required this.projectId, required this.alreadyAssigned});

  @override
  State<_AssignOfficerSheet> createState() => _AssignOfficerSheetState();
}

class _AssignOfficerSheetState extends State<_AssignOfficerSheet> {
  List<ManagedUser>? _officers;
  bool _failed = false;
  int? _selectedId;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    try {
      final page = await context.read<UserRepository>().list();
      if (!mounted) return;
      setState(() {
        _officers = page.results
            .where((u) =>
                u.role == 'officer' &&
                u.isActive &&
                !widget.alreadyAssigned.contains(u.id))
            .toList();
      });
    } on ApiException {
      if (mounted) setState(() => _failed = true);
    }
  }

  Future<void> _save() async {
    if (_selectedId == null) return;
    setState(() => _busy = true);
    try {
      await context
          .read<ProjectRepository>()
          .assign(widget.projectId, _selectedId!);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final officers = _officers;
    return _SheetScaffold(
      title: 'Assign Officer',
      busy: _busy,
      onSave: _selectedId == null ? null : _save,
      child: _failed
          ? Row(
              children: [
                const Expanded(child: Text('Failed to load officers.')),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          : officers == null
              ? const Center(child: CircularProgressIndicator())
              : officers.isEmpty
                  ? const Text('No unassigned active officers found.')
                  : Column(
                      children: [
                        for (final u in officers)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              _selectedId == u.id
                                  ? Icons.radio_button_checked
                                  : Icons.radio_button_unchecked,
                              color: _selectedId == u.id
                                  ? AppColors.primary
                                  : AppColors.muted,
                            ),
                            title: Text(u.fullName),
                            subtitle: Text(u.email),
                            onTap: () => setState(() => _selectedId = u.id),
                          ),
                      ],
                    ),
    );
  }
}

/// Shared bottom-sheet chrome: title, content, Cancel/Save actions.
class _SheetScaffold extends StatelessWidget {
  final String title;
  final Widget child;
  final bool busy;
  final VoidCallback? onSave;

  const _SheetScaffold({
    required this.title,
    required this.child,
    required this.busy,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Flexible(child: SingleChildScrollView(child: child)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : onSave,
                  child: busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Save'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _emptyState(BuildContext context, IconData icon, String message) {
  return Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 52, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 12),
        Text(message, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}
