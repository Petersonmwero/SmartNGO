import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/constants/app_theme_data.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../../shared/widgets/kenya_location_picker.dart';
import '../../projects/models/project.dart';
import '../../projects/project_repository.dart';
import '../beneficiary_repository.dart';

/// Beneficiary registration form: Personal Details, Location Details
/// (cascading Kenya picker), and Project Assignment section cards.
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
  String _gender = 'female';
  DateTime? _dob;
  int? _projectId;
  bool _busy = false;
  Map<String, String> _location = const {};

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
        county: _location['county'] ?? '',
        constituency: _location['constituency'] ?? '',
        ward: _location['ward'] ?? '',
        location: _location['location'] ?? '',
        subLocation: _location['sub_location'] ?? '',
        village: _location['village'] ?? '',
      );
      if (!mounted) return;
      showSuccessSnackBar(context, 'Beneficiary registered successfully!');
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionCard(
                title: 'Personal Details',
                icon: Icons.person_outline,
                children: [
                  BlurValidatedTextField(
                    key: const Key('beneficiary_name'),
                    controller: _name,
                    decoration: AppThemeData.inputDecoration(
                        'Full name', Icons.person_outline),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                  const SizedBox(height: 12),
                  Text('Gender',
                      style: Theme.of(context).textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(
                          value: 'female',
                          label: Text('Female'),
                          icon: Icon(Icons.female)),
                      ButtonSegment(
                          value: 'male',
                          label: Text('Male'),
                          icon: Icon(Icons.male)),
                      ButtonSegment(
                          value: 'other',
                          label: Text('Other'),
                          icon: Icon(Icons.person)),
                    ],
                    selected: {_gender},
                    onSelectionChanged: (s) =>
                        setState(() => _gender = s.first),
                    style: SegmentedButton.styleFrom(
                      selectedBackgroundColor: AppColors.primary,
                      selectedForegroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DobField(
                    dob: _dob,
                    age: _computedAge,
                    onTap: _pickDob,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: AppThemeData.inputDecoration(
                        'Phone (optional)', Icons.phone_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Location Details',
                icon: Icons.location_on_outlined,
                children: [
                  KenyaLocationPicker(
                    onChanged: (data) => _location = data,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Project Assignment',
                icon: Icons.folder_outlined,
                children: [
                  if (_projectsFailed)
                    Row(
                      children: [
                        const Expanded(
                            child: Text('Failed to load projects.')),
                        TextButton(
                            onPressed: _loadProjects,
                            child: const Text('Retry')),
                      ],
                    )
                  else
                    DropdownButtonFormField<int>(
                      key: const Key('project_selector'),
                      initialValue: _projectId,
                      decoration: AppThemeData.inputDecoration(
                          'Assign to Project', Icons.folder_outlined),
                      items: [
                        for (final p in _projects ?? const <Project>[])
                          DropdownMenuItem(
                              value: p.id, child: Text(p.projectName)),
                        // Keep a pre-selected project visible while loading.
                        if (_projects == null && _projectId != null)
                          DropdownMenuItem(
                              value: _projectId,
                              child: Text('Project $_projectId')),
                      ],
                      onChanged: (v) => setState(() => _projectId = v),
                      validator: (v) => v == null ? 'Select a project' : null,
                    ),
                ],
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
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.person_add, size: 20),
                          SizedBox(width: 8),
                          Text('Register Beneficiary'),
                        ],
                      ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

/// Date-of-birth row with a live computed-age chip.
class _DobField extends StatelessWidget {
  final DateTime? dob;
  final int? age;
  final VoidCallback onTap;

  const _DobField({required this.dob, required this.age, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: const Key('dob_field'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFD1D5DB)),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Date of Birth',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 11, color: AppColors.muted)),
                Text(
                  dob == null
                      ? 'Tap to select'
                      : DateFormat('d MMM yyyy').format(dob!),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: dob == null
                            ? AppColors.muted
                            : AppColors.charcoal,
                        fontWeight:
                            dob == null ? null : FontWeight.w700,
                      ),
                ),
              ],
            ),
            const Spacer(),
            if (age != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Age: $age',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontSize: 12,
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// White card with an icon-badge header and a hairline divider above its
/// content — groups the form into titled sections.
class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> children;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppThemeData.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: AppColors.primary, size: 18),
                ),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF3F4F6)),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ],
      ),
    );
  }
}
