import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../beneficiary_repository.dart';

class RegisterBeneficiaryScreen extends StatefulWidget {
  /// Optional pre-selected project (e.g. opened from a project).
  final int? projectId;

  const RegisterBeneficiaryScreen({super.key, this.projectId});

  @override
  State<RegisterBeneficiaryScreen> createState() =>
      _RegisterBeneficiaryScreenState();
}

class _RegisterBeneficiaryScreenState extends State<RegisterBeneficiaryScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _location = TextEditingController();
  final _projectId = TextEditingController();
  String _gender = 'female';
  DateTime? _dob;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.projectId != null) {
      _projectId.text = widget.projectId.toString();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _location.dispose();
    _projectId.dispose();
    super.dispose();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
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
        projectId: int.parse(_projectId.text.trim()),
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
            DropdownButtonFormField<String>(
              initialValue: _gender,
              decoration: const InputDecoration(labelText: 'Gender'),
              items: const [
                DropdownMenuItem(value: 'female', child: Text('Female')),
                DropdownMenuItem(value: 'male', child: Text('Male')),
                DropdownMenuItem(value: 'other', child: Text('Other')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'female'),
            ),
            const SizedBox(height: 16),
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
            const SizedBox(height: 16),
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Location'),
            ),
            const SizedBox(height: 16),
            BlurValidatedTextField(
              controller: _projectId,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Project ID'),
              validator: (v) => (v == null || int.tryParse(v) == null)
                  ? 'Enter a numeric Project ID'
                  : null,
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
                  : const Text('Register'),
            ),
          ],
        ),
      ),
    );
  }
}
