import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../ngos/ngo_repository.dart';
import '../auth_repository.dart';

/// Allowed self-registration roles (mirrors backend SELF_REGISTRABLE_ROLES).
const _roles = [
  _RoleOption('officer', 'Field Officer',
      'You will be assigned to projects by your manager'),
  _RoleOption('manager', 'Project Manager',
      'You can create and manage projects'),
  _RoleOption('donor', 'Donor',
      'You will have read-only access to funded projects'),
];

class _RoleOption {
  final String value;
  final String label;
  final String helper;
  const _RoleOption(this.value, this.label, this.helper);
}

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String _role = 'officer';
  int? _selectedNgoId;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _busy = false;

  // NGO dropdown state
  List<NgoPublic>? _ngos;
  bool _loadingNgos = true;
  bool _ngosError = false;

  // Post-registration success state
  bool _showSuccess = false;
  String _registeredEmail = '';
  String _registeredFirstName = '';

  @override
  void initState() {
    super.initState();
    _loadNgos();
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _loadNgos() async {
    setState(() {
      _loadingNgos = true;
      _ngosError = false;
    });
    try {
      final ngos = await context.read<NgoRepository>().listPublic();
      if (!mounted) return;
      setState(() {
        _ngos = ngos;
        _loadingNgos = false;
      });
    } on ApiException {
      if (!mounted) return;
      setState(() {
        _loadingNgos = false;
        _ngosError = true;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedNgoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your NGO')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<AuthRepository>().register(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
            ngoId: _selectedNgoId!,
          );
      if (!mounted) return;
      setState(() {
        _showSuccess = true;
        _registeredEmail = _email.text.trim();
        _registeredFirstName = _firstName.text.trim();
      });
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
    if (_showSuccess) return _SuccessScreen(email: _registeredEmail, firstName: _registeredFirstName);

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Branding header
            SizedBox(
              height: MediaQuery.sizeOf(context).height * 0.22,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.eco_rounded, size: 40, color: Colors.white),
                    const SizedBox(height: 10),
                    Text(
                      'Create Account',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Smart NGO M&E Platform',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Form card
            Expanded(
              child: Container(
                decoration: const BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Back button row
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => Navigator.of(context).pop(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const SizedBox(width: 8),
                            Text('Back to login',
                                style: Theme.of(context).textTheme.bodyMedium),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Name row: first name + last name side-by-side
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _firstName,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'First name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                                validator: (v) =>
                                    (v == null || v.trim().isEmpty) ? 'Required' : null,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: _lastName,
                                textInputAction: TextInputAction.next,
                                decoration: const InputDecoration(
                                  labelText: 'Last name',
                                ),
                                validator: (v) => null, // optional
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email
                        TextFormField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) => (v == null || !v.contains('@'))
                              ? 'Enter a valid email'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Password
                        TextFormField(
                          controller: _password,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          validator: (v) => (v == null || v.length < 8)
                              ? 'At least 8 characters'
                              : null,
                        ),
                        const SizedBox(height: 16),

                        // Confirm password
                        TextFormField(
                          controller: _confirmPassword,
                          obscureText: _obscureConfirm,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Confirm password',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirm
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            if (v != _password.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Role selector
                        DropdownButtonFormField<String>(
                          key: const Key('role_selector'),
                          initialValue: _role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          items: _roles
                              .map((r) => DropdownMenuItem(
                                    value: r.value,
                                    child: Text(r.label),
                                  ))
                              .toList(),
                          onChanged: (v) =>
                              setState(() => _role = v ?? 'officer'),
                          validator: (v) => v == null ? 'Select a role' : null,
                        ),
                        // Role helper text
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 6),
                          child: Text(
                            _roles
                                .firstWhere((r) => r.value == _role)
                                .helper,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: AppColors.muted),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // NGO dropdown
                        if (_loadingNgos)
                          const _NgoLoadingPlaceholder()
                        else if (_ngosError)
                          _NgoErrorState(onRetry: _loadNgos)
                        else
                          DropdownButtonFormField<int>(
                            key: const Key('ngo_selector'),
                            initialValue: _selectedNgoId,
                            decoration: const InputDecoration(
                              labelText: 'Organisation (NGO)',
                              prefixIcon: Icon(Icons.domain_outlined),
                            ),
                            items: (_ngos ?? [])
                                .map((n) => DropdownMenuItem(
                                      value: n.id,
                                      child: Text(n.name),
                                    ))
                                .toList(),
                            onChanged: (v) =>
                                setState(() => _selectedNgoId = v),
                            validator: (v) =>
                                v == null ? 'Select your organisation' : null,
                          ),
                        const SizedBox(height: 28),

                        FilledButton(
                          onPressed: (_busy || _loadingNgos) ? null : _submit,
                          child: _busy
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Create account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _NgoLoadingPlaceholder extends StatelessWidget {
  const _NgoLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Organisation (NGO)',
        prefixIcon: Icon(Icons.domain_outlined),
      ),
      child: Row(
        children: [
          const SizedBox(
              height: 16,
              width: 16,
              child: CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(width: 12),
          Text('Loading organisations…',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _NgoErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _NgoErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Failed to load organisations.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppColors.error)),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Retry'),
        ),
      ],
    );
  }
}

/// Shown in place of the form after successful registration.
class _SuccessScreen extends StatelessWidget {
  final String email;
  final String firstName;
  const _SuccessScreen({required this.email, required this.firstName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mark_email_read_outlined,
                    size: 44,
                    color: AppColors.success,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  firstName.isNotEmpty ? 'Welcome, $firstName!' : 'Account Created!',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  "We've sent a verification email to:\n$email\n\n"
                  "Check your inbox and click the link to activate "
                  "your account before logging in.",
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    color: AppColors.muted,
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
