import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../models/phase.dart';
import '../project_repository.dart';
import '../widgets/evm_cards.dart';

/// Manager/Admin screen for a project's budget phases. Any spend edit here
/// immediately moves the project's financial progress on the detail screen
/// (progress is computed server-side from phase spend).
class PhaseManagementScreen extends StatefulWidget {
  final int projectId;
  final String projectName;

  const PhaseManagementScreen({
    super.key,
    required this.projectId,
    required this.projectName,
  });

  @override
  State<PhaseManagementScreen> createState() => _PhaseManagementScreenState();
}

class _PhaseManagementScreenState extends State<PhaseManagementScreen> {
  late final ProjectRepository _repo;
  late Future<List<ProjectPhase>> _future;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ProjectRepository>();
    _load();
  }

  void _load() => _future = _repo.phases(widget.projectId);

  Future<void> _openForm({ProjectPhase? phase}) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PhaseFormSheet(projectId: widget.projectId, phase: phase),
    );
    if (saved == true && mounted) {
      _changed = true;
      setState(_load);
      showSuccessSnackBar(
          context, 'Phase updated — project progress recalculated');
    }
  }

  Future<void> _delete(ProjectPhase phase) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete phase'),
        content: Text('Delete "${phase.phaseName}"? Its spend will no longer '
            'count towards financial progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await _repo.deletePhase(widget.projectId, phase.id);
      if (!mounted) return;
      _changed = true;
      setState(_load);
      showSuccessSnackBar(
          context, 'Phase deleted — project progress recalculated');
    } on ApiException catch (e) {
      if (mounted) showErrorSnackBar(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('MANAGE PHASES'),
              Text(
                widget.projectName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, letterSpacing: 0.2),
              ),
            ],
          ),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Add Phase'),
        ),
        body: FutureBuilder<List<ProjectPhase>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const ShimmerList(cardHeight: 88);
            }
            if (snapshot.hasError) {
              final err = snapshot.error;
              return EmptyState(
                Icons.cloud_off_outlined,
                'Something went wrong',
                err is ApiException ? err.message : 'Failed to load phases.',
                buttonLabel: 'Retry',
                onButton: () => setState(_load),
              );
            }
            final phases = snapshot.data ?? [];
            if (phases.isEmpty) {
              return EmptyState(
                Icons.account_tree_outlined,
                'No phases yet',
                'Break the project budget into phases to track '
                    'financial progress.',
                buttonLabel: 'Add Phase',
                onButton: () => _openForm(),
              );
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
              itemCount: phases.length,
              itemBuilder: (_, i) => _PhaseCard(
                phase: phases[i],
                onEdit: () => _openForm(phase: phases[i]),
                onDelete: () => _delete(phases[i]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PhaseCard extends StatelessWidget {
  final ProjectPhase phase;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PhaseCard(
      {required this.phase, required this.onEdit, required this.onDelete});

  Color get _statusColor => switch (phase.status) {
        'completed' => AppColors.success,
        'in_progress' => AppColors.info,
        _ => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(phase.phaseName,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                    Text(phase.typeLabel,
                        style: const TextStyle(
                            fontSize: 10, color: AppColors.textMuted)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  border: Border.all(color: _statusColor),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  phase.statusLabel.toUpperCase(),
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                      color: _statusColor),
                ),
              ),
              IconButton(
                tooltip: 'Edit phase',
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: AppColors.primary),
                onPressed: onEdit,
              ),
              IconButton(
                tooltip: 'Delete phase',
                icon: const Icon(Icons.delete_outline,
                    size: 18, color: AppColors.danger),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${formatKes(phase.spentBudget)} spent of '
            '${formatKes(phase.allocatedBudget)} allocated '
            '(${phase.utilizationPercentage.round()}%)',
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (phase.utilizationPercentage / 100).clamp(0.0, 1.0),
            backgroundColor: AppColors.border,
            color: _statusColor,
            minHeight: 5,
          ),
        ],
      ),
    );
  }
}

// ── Add / Edit form ────────────────────────────────────────────────────────

class _PhaseFormSheet extends StatefulWidget {
  final int projectId;
  final ProjectPhase? phase;

  const _PhaseFormSheet({required this.projectId, this.phase});

  @override
  State<_PhaseFormSheet> createState() => _PhaseFormSheetState();
}

class _PhaseFormSheetState extends State<_PhaseFormSheet> {
  static const _types = {
    'planning': 'Planning',
    'implementation': 'Implementation',
    'monitoring': 'Monitoring & Evaluation',
    'closeout': 'Closeout',
  };
  static const _statuses = {
    'not_started': 'Not Started',
    'in_progress': 'In Progress',
    'completed': 'Completed',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _allocated;
  late final TextEditingController _spent;
  late String _type;
  late String _status;
  DateTime? _start;
  DateTime? _end;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final p = widget.phase;
    _name = TextEditingController(text: p?.phaseName ?? '');
    _allocated = TextEditingController(
        text: p == null ? '' : p.allocatedBudget.toStringAsFixed(0));
    _spent = TextEditingController(
        text: p == null ? '' : p.spentBudget.toStringAsFixed(0));
    _type = p?.phaseType ?? 'implementation';
    _status = p?.status ?? 'not_started';
    _start = DateTime.tryParse(p?.startDate ?? '');
    _end = DateTime.tryParse(p?.endDate ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _allocated.dispose();
    _spent.dispose();
    super.dispose();
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return 'Required';
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return 'Enter a valid amount';
    if (parsed < 0) return 'Must not be negative';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final fmt = DateFormat('yyyy-MM-dd');
    final data = {
      'phase_name': _name.text.trim(),
      'phase_type': _type,
      'allocated_budget': _allocated.text.trim(),
      'spent_budget': _spent.text.trim(),
      'start_date': fmt.format(_start!),
      'end_date': fmt.format(_end!),
      'status': _status,
    };
    try {
      final repo = context.read<ProjectRepository>();
      if (widget.phase == null) {
        await repo.createPhase(widget.projectId, data);
      } else {
        await repo.updatePhase(widget.projectId, widget.phase!.id, data);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
        setState(() => _busy = false);
      }
    }
  }

  Widget _datePicker(String label, DateTime? value,
      ValueChanged<DateTime> onPicked) {
    return FormField<DateTime>(
      validator: (_) => value == null ? 'Pick a date' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.event_outlined, size: 18),
            label: Text(value != null
                ? DateFormat('yyyy-MM-dd').format(value)
                : label),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: value ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPicked(picked);
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
    );
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.phase != null;
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
          Text(editing ? 'Edit Phase' : 'Add Phase',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          Flexible(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _name,
                      decoration:
                          const InputDecoration(labelText: 'Phase name'),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _type,
                      decoration:
                          const InputDecoration(labelText: 'Phase type'),
                      items: [
                        for (final e in _types.entries)
                          DropdownMenuItem(
                              value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _type = v!),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _allocated,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Allocated budget (KES)'),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _spent,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                          labelText: 'Spent budget (KES)'),
                      validator: _validateAmount,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _datePicker('Start date', _start,
                              (d) => setState(() => _start = d)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _datePicker('End date', _end,
                              (d) => setState(() => _end = d)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: [
                        for (final e in _statuses.entries)
                          DropdownMenuItem(
                              value: e.key, child: Text(e.value)),
                      ],
                      onChanged: (v) => setState(() => _status = v!),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
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
