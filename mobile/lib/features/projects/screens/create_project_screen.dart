import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../project_repository.dart';

/// Multi-step form to create a new project.
///
/// Step 1: Name + Description
/// Step 2: Budget
/// Step 3: Dates + Status
class CreateProjectScreen extends StatefulWidget {
  const CreateProjectScreen({super.key});

  @override
  State<CreateProjectScreen> createState() => _CreateProjectScreenState();
}

class _CreateProjectScreenState extends State<CreateProjectScreen> {
  int _step = 0;
  bool _saving = false;

  // Step 1
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _form1Key = GlobalKey<FormState>();

  // Step 2
  final _budgetCtrl = TextEditingController();
  final _form2Key = GlobalKey<FormState>();

  // Step 3
  DateTime? _startDate;
  DateTime? _endDate;
  String _status = 'planning';
  final _form3Key = GlobalKey<FormState>();

  static const _statuses = {
    'planning': 'Planning',
    'active': 'Active',
    'on_hold': 'On Hold',
  };

  final _fmt = DateFormat('yyyy-MM-dd');

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _budgetCtrl.dispose();
    super.dispose();
  }

  void _next() {
    if (_step == 0 && !(_form1Key.currentState?.validate() ?? false)) return;
    if (_step == 1 && !(_form2Key.currentState?.validate() ?? false)) return;
    if (_step == 2) {
      _submit();
      return;
    }
    setState(() => _step++);
  }

  Future<void> _submit() async {
    if (!(_form3Key.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    try {
      await context.read<ProjectRepository>().create(
            name: _nameCtrl.text.trim(),
            description: _descCtrl.text.trim(),
            budget: double.parse(_budgetCtrl.text.trim()),
            startDate: _fmt.format(_startDate!),
            endDate: _fmt.format(_endDate!),
            status: _status,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Project created successfully.')),
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create project: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate(bool isStart) async {
    final initial = isStart ? (_startDate ?? DateTime.now()) : (_endDate ?? DateTime.now());
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
    return Scaffold(
      appBar: AppBar(title: const Text('New Project')),
      body: Column(
        children: [
          // Step indicator
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
            child: Row(
              children: [
                for (int i = 0; i < 3; i++) ...[
                  _StepDot(index: i, current: _step, labels: const ['Details', 'Budget', 'Timeline']),
                  if (i < 2)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: _step > i ? AppColors.primary : AppColors.border,
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
              child: IndexedStack(
                index: _step,
                children: [_Step1(formKey: _form1Key, nameCtrl: _nameCtrl, descCtrl: _descCtrl),
                  _Step2(formKey: _form2Key, budgetCtrl: _budgetCtrl),
                  _Step3(
                    formKey: _form3Key,
                    startDate: _startDate,
                    endDate: _endDate,
                    status: _status,
                    onPickStart: () => _pickDate(true),
                    onPickEnd: () => _pickDate(false),
                    onStatusChanged: (v) => setState(() => _status = v),
                    statuses: _statuses,
                    fmt: _fmt,
                  ),
                ],
              ),
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
                        : Text(_step == 2 ? 'Create Project' : 'Next'),
                  ),
                ),
              ],
            ),
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
  const _StepDot({required this.index, required this.current, required this.labels});

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

class _Step1 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController nameCtrl;
  final TextEditingController descCtrl;
  const _Step1({required this.formKey, required this.nameCtrl, required this.descCtrl});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Project Details', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(
            controller: nameCtrl,
            decoration: const InputDecoration(labelText: 'Project Name *'),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: descCtrl,
            decoration: const InputDecoration(labelText: 'Description'),
            maxLines: 4,
          ),
        ],
      ),
    );
  }
}

class _Step2 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController budgetCtrl;
  const _Step2({required this.formKey, required this.budgetCtrl});

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Budget', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(
            controller: budgetCtrl,
            decoration: const InputDecoration(
              labelText: 'Total Budget (KES) *',
              prefixIcon: Icon(Icons.attach_money),
            ),
            keyboardType: TextInputType.number,
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Required';
              if (double.tryParse(v.trim()) == null) return 'Enter a valid number';
              return null;
            },
          ),
        ],
      ),
    );
  }
}

class _Step3 extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final VoidCallback onPickStart;
  final VoidCallback onPickEnd;
  final ValueChanged<String> onStatusChanged;
  final Map<String, String> statuses;
  final DateFormat fmt;

  const _Step3({
    required this.formKey,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.onPickStart,
    required this.onPickEnd,
    required this.onStatusChanged,
    required this.statuses,
    required this.fmt,
  });

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Timeline & Status', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          FormField<DateTime>(
            validator: (_) => startDate == null ? 'Pick a start date' : null,
            builder: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickStart,
                  icon: const Icon(Icons.calendar_today_outlined, size: 18),
                  label: Text(startDate != null ? fmt.format(startDate!) : 'Start Date *'),
                ),
                if (state.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(state.errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FormField<DateTime>(
            validator: (_) {
              if (endDate == null) return 'Pick an end date';
              if (startDate != null && !endDate!.isAfter(startDate!)) {
                return 'End date must be after start date';
              }
              return null;
            },
            builder: (state) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                OutlinedButton.icon(
                  onPressed: onPickEnd,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(endDate != null ? fmt.format(endDate!) : 'End Date *'),
                ),
                if (state.errorText != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, top: 4),
                    child: Text(state.errorText!,
                        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Initial Status', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            children: statuses.entries.map((e) {
              return ChoiceChip(
                label: Text(e.value),
                selected: status == e.key,
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: status == e.key ? Colors.white : null,
                ),
                onSelected: (_) => onStatusChanged(e.key),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
