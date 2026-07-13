import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../projects/models/project.dart';
import '../../projects/project_repository.dart';
import '../beneficiary_repository.dart';

class RegisterBeneficiaryScreen extends StatefulWidget {
  /// Optional pre-selected project (e.g. opened from a project).
  final int? projectId;

  const RegisterBeneficiaryScreen({super.key, this.projectId});

  @override
  State<RegisterBeneficiaryScreen> createState() =>
      _RegisterBeneficiaryScreenState();
}

class _RegisterBeneficiaryScreenState
    extends State<RegisterBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  String _gender = 'female';
  DateTime? _dob;
  int? _projectId;
  bool _busy = false;

  // Project selector state.
  List<Project>? _projects;
  bool _projectsFailed = false;

  @override
  void initState() {
    super.initState();
    _projectId = widget.projectId;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadProjects());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    super.dispose();
  }

  Future<void> _loadProjects() async {
    setState(() => _projectsFailed = false);
    try {
      final page = await context.read<ProjectRepository>().list();
      if (!mounted) return;
      setState(() => _projects = page.results);
    } on ApiException {
      if (mounted) setState(() => _projectsFailed = true);
    }
  }

  /// Same algorithm the backend uses for the computed `age` field.
  int? get _computedAge {
    final dob = _dob;
    if (dob == null) return null;
    final today = DateTime.now();
    var age = today.year - dob.year;
    if (today.month < dob.month ||
        (today.month == dob.month && today.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _dob ?? DateTime(now.year - 20),
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) setState(() => _dob = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    final repo = context.read<BeneficiaryRepository>();
    try {
      await repo.create(
        projectId: _projectId!,
        name: _name.text.trim(),
        gender: _gender,
        dateOfBirth:
            _dob == null ? null : DateFormat('yyyy-MM-dd').format(_dob!),
        phone: _phone.text.trim(),
        location: _location.text.trim(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Beneficiary registered.')),
      );
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register Beneficiary')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            BlurValidatedTextField(
              key: const Key('beneficiary_name'),
              controller: _name,
              decoration: const InputDecoration(labelText: 'Full name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            // Gender segmented selector.
            Text('Gender', style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'female', label: Text('Female')),
                ButtonSegment(value: 'male', label: Text('Male')),
                ButtonSegment(value: 'other', label: Text('Other')),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => setState(() => _gender = s.first),
            ),
            const SizedBox(height: 16),
            // Date of birth with computed age preview.
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Date of birth'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_dob == null
                      ? 'Not set'
                      : DateFormat('yyyy-MM-dd').format(_dob!)),
                  TextButton(onPressed: _pickDob, child: const Text('Pick')),
                ],
              ),
            ),
            if (_computedAge != null)
              Padding(
                padding: const EdgeInsets.only(left: 12, top: 4),
                child: Text(
                  'Age: $_computedAge years',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.primary),
                ),
              ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration:
                  const InputDecoration(labelText: 'Phone (optional)'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration:
                  const InputDecoration(labelText: 'Location / Village'),
            ),
            const SizedBox(height: 16),
            // Project selector.
            if (_projectsFailed)
              Row(
                children: [
                  const Expanded(child: Text('Failed to load projects.')),
                  TextButton(
                      onPressed: _loadProjects, child: const Text('Retry')),
                ],
              )
            else
              DropdownButtonFormField<int>(
                key: const Key('project_selector'),
                initialValue: _projectId,
                decoration: const InputDecoration(labelText: 'Project'),
                items: [
                  for (final p in _projects ?? const <Project>[])
                    DropdownMenuItem(value: p.id, child: Text(p.projectName)),
                  // Keep a pre-selected project visible while the list loads.
                  if (_projects == null && _projectId != null)
                    DropdownMenuItem(
                        value: _projectId, child: Text('Project $_projectId')),
                ],
                onChanged: (v) => setState(() => _projectId = v),
                validator: (v) => v == null ? 'Select a project' : null,
              ),
            const SizedBox(height: 24),
            FilledButton(
              key: const Key('register_beneficiary_button'),
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Register Beneficiary'),
            ),
          ],
        ),
      ),
    );
  }
}
