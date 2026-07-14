import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../users/user_repository.dart';
import '../models/project.dart';
import '../project_repository.dart';

/// Multi-step form to create (or edit) a project.
///
/// Step 1: Details (name, description, status)
/// Step 2: Budget & Timeline
/// Step 3: Team (assign officers; create mode only)
class CreateProjectScreen extends StatefulWidget {
  /// When set, the form edits this project instead of creating a new one.
  final Project? project;

  const CreateProjectScreen({super.key, this.project});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  static const _labels = ['Details', 'Budget & Timeline', 'Team'];
  static const _maxDescriptionLength = 500;

  int _step = 0;
  bool _saving = false;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  String _status = 'planning';
  final _form1Key = GlobalKey<FormState>();

  // Step 2
  final _budgetCtrl = TextEditingController();
  DateTime? _startDate;
  DateTime? _endDate;
  final _form2Key = GlobalKey<FormState>();

  // Step 3 — officer picker. Null while loading; empty on load failure
  // (managers may not be able to see the user list on older backends).
  List<ManagedUser>? _officers;
  bool _officersFailed = false;
  final Set<int> _selectedOfficerIds = {};

  static const _statuses = {
    'planning': 'Planning',
    'active': 'Active',
    'on_hold': 'On Hold',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  final _fmt = DateFormat('yyyy-MM-dd');

  bool get _isEdit => widget.project != null;

  @override
  void initState() {
    super.initState();
    final p = widget.project;
    if (p != null) {
      _nameCtrl.text = p.projectName;
      _descCtrl.text = p.description;
      _budgetCtrl.text = p.budget;
      _status = p.status;
      _startDate = DateTime.tryParse(p.startDate ?? '');
      _endDate = DateTime.tryParse(p.endDate ?? '');
    }
    if (!_isEdit) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadOfficers());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadOfficers() async {
    try {
      final page = await context.read<UserRepository>().list();
      if (!mounted) return;
      setState(() {
        _officers = page.results
            .where((u) => u.role == 'officer' && u.isActive)
            .toList();
      });
    } on ApiException {
      if (mounted) setState(() => _officersFailed = true);
    }
  }

  void _next() {
    if (_step == 0 && !(_form1Key.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_form2Key.currentState?.validate() ?? false)) return;
    final lastStep = _isEdit ? 1 : 2;
    if (_step == lastStep) {
      _submit();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    final repo = context.read<ProjectRepository>();
    try {
      if (_isEdit) {
        await repo.update(
          widget.project!.id,
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          budget: double.parse(_budgetCtrl.text.trim()),
          startDate: _fmt.format(_startDate!),
          endDate: _fmt.format(_endDate!),
          status: _status,
        );
      } else {
        final project = await repo.create(
          name: _nameCtrl.text.trim(),
          description: _descCtrl.text.trim(),
          budget: double.parse(_budgetCtrl.text.trim()),
          startDate: _fmt.format(_startDate!),
          endDate: _fmt.format(_endDate!),
          status: _status,
        );
        for (final userId in _selectedOfficerIds) {
          await repo.assign(project.id, userId);
        }
      }
      if (!mounted) return;
      showSuccessSnackBar(
          context,
          _isEdit
              ? 'Project updated successfully!'
              : 'Project created successfully!');
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      final msg = e is ApiException ? e.message : '$e';
      showErrorSnackBar(context, 'Failed to save project: $msg');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial =
        isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
      } else {
        _endDate = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final stepCount = _isEdit ? 2 : 3;
    final lastStep = stepCount - 1;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Project' : 'New Project')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                for (int i = 0; i < stepCount; i++) ...[
                  _StepDot(index: i, current: _step, labels: _labels),
                  if (i < stepCount - 1)
                    Expanded(
                      child: Container(
                        height: 2,
                        color:
                            _step > i ? AppColors.primary : AppColors.border,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                      ),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: switch (_step) {
                0 => _buildDetails(),
                1 => _buildBudgetTimeline(),
                _ => _buildTeam(),
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (_step > 0)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() => _step--),
                      child: const Text('Back'),
                    ),
                  ),
                if (_step > 0) const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : _next,
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : Text(_step == lastStep
                            ? (_isEdit ? 'Save Changes' : 'Create Project')
                            : 'Next'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Step 1: Details ──────────────────────────────────────────────────

  Widget _buildDetails() {
    return Form(
      key: _form1Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project Details',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          BlurValidatedTextField(
            controller: _nameCtrl,
            decoration: const InputDecoration(labelText: 'Project Name *'),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _descCtrl,
            decoration: const InputDecoration(
              labelText: 'Description',
              alignLabelWithHint: true,
            ),
            maxLines: 4,
            maxLength: _maxDescriptionLength,
          ),
          const SizedBox(height: 4),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [
              for (final e in _statuses.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _status = v ?? 'planning'),
          ),
        ],
      ),
    );
  }

  // ── Step 2: Budget & Timeline ────────────────────────────────────────

  Widget _buildBudgetTimeline() {
    return Form(
      key: _form2Key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget & Timeline',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          BlurValidatedTextField(
            controller: _budgetCtrl,
            decoration: const InputDecoration(
              labelText: 'Total Budget *',
              prefixText: 'KES ',
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              final parsed = double.tryParse(v.trim());
              if (parsed == null) return 'Enter a valid number';
              if (parsed <= 0) return 'Budget must be positive';
              return null;
            },
          ),
          const SizedBox(height: 20),
          _DateField(
            label: 'Start Date *',
            icon: Icons.calendar_today_outlined,
            value: _startDate,
            fmt: _fmt,
            onPick: () => _pickDate(true),
            validator: (_) => _startDate == null ? 'Pick a start date' : null,
          ),
          const SizedBox(height: 12),
          _DateField(
            label: 'End Date *',
            icon: Icons.event_outlined,
            value: _endDate,
            fmt: _fmt,
            onPick: () => _pickDate(false),
            validator: (_) {
              if (_endDate == null) return 'Pick an end date';
              if (_startDate != null && !_endDate!.isAfter(_startDate!)) {
                return 'End date must be after start date';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  // ── Step 3: Team ─────────────────────────────────────────────────────

  Widget _buildTeam() {
    final officers = _officers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Assign Officers', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          'Selected officers are added to the project team on creation. '
          'This step is optional.',
          style: Theme.of(context)
              .textTheme
              .bodySmall
              ?.copyWith(color: AppColors.muted),
        ),
        const SizedBox(height: 20),
        if (_officersFailed)
          Text(
            'Could not load the officer list. You can assign officers from '
            "the project's Team tab after creation.",
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          )
        else if (officers == null)
          const Center(child: CircularProgressIndicator())
        else if (officers.isEmpty)
          Text(
            'No active field officers found in your NGO.',
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          )
        else ...[
          if (_selectedOfficerIds.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final u in officers
                    .where((u) => _selectedOfficerIds.contains(u.id)))
                  Chip(
                    label: Text(u.fullName),
                    onDeleted: () =>
                        setState(() => _selectedOfficerIds.remove(u.id)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          for (final u in officers)
            CheckboxListTile(
              value: _selectedOfficerIds.contains(u.id),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(u.fullName),
              subtitle: Text(u.email,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted)),
              onChanged: (checked) => setState(() {
                if (checked == true) {
                  _selectedOfficerIds.add(u.id);
                } else {
                  _selectedOfficerIds.remove(u.id);
                }
              }),
            ),
        ],
      ],
    );
  }
}

/// Outlined date picker button that participates in Form validation.
class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final DateFormat fmt;
  final VoidCallback onPick;
  final FormFieldValidator<DateTime> validator;

  const _DateField({
    required this.label,
    required this.icon,
    required this.value,
    required this.fmt,
    required this.onPick,
    required this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return FormField<DateTime>(
      validator: validator,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OutlinedButton.icon(
            onPressed: onPick,
            icon: Icon(icon, size: 18),
            label: Text(value != null ? fmt.format(value!) : label),
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
}

class _StepDot extends StatelessWidget {
  final int index;
  final int current;
  final List<String> labels;
  const _StepDot(
      {required this.index, required this.current, required this.labels});

  @override
  Widget build(BuildContext context) {
    final done = current > index;
    final active = current == index;
    final color = (done || active) ? AppColors.primary : AppColors.border;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Center(
            child: done
                ? const Icon(Icons.check, size: 16, color: Colors.white)
                : Text('${index + 1}',
                    style: TextStyle(
                        color: active ? Colors.white : AppColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 4),
        Text(labels[index],
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: active ? AppColors.primary : AppColors.muted)),
      ],
    );
  }
}
