import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/blur_validated_text_field.dart';
import '../../../shared/widgets/official_card.dart';
import '../auth_provider.dart';
import '../auth_repository.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// Official eCitizen-style login: government header with the Kenya flag
/// ribbon and system identity, a bordered SYSTEM LOGIN card, and the
/// institutional footer.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscure = true;
  bool _showResend = false;
  bool _resendBusy = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _showResend = false);
    final auth = context.read<AuthProvider>();
    final ok = await auth.login(
      _emailController.text.trim(),
      _passwordController.text,
    );
    if (!ok && mounted) {
      if (auth.errorCode == 'EMAIL_NOT_VERIFIED') {
        setState(() => _showResend = true);
        showErrorSnackBar(
            context, 'Please verify your email first. Check your inbox.');
      } else {
        showErrorSnackBar(context, auth.error ?? 'Login failed');
      }
    }
  }

  Future<void> _resendVerification() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showErrorSnackBar(context, 'Enter your email above first');
      return;
    }
    setState(() => _resendBusy = true);
    try {
      await context.read<AuthRepository>().resendVerification(email);
      if (!mounted) return;
      showSuccessSnackBar(
          context, 'Verification email resent. Check your inbox.');
    } on ApiException catch (e) {
      if (!mounted) return;
      showErrorSnackBar(context, e.message);
    } finally {
      if (mounted) setState(() => _resendBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _GovernmentHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Login card.
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: AppColors.surfaceVariant,
                            border: Border(
                              bottom: BorderSide(color: AppColors.border),
                              left: BorderSide(
                                  color: AppColors.primary, width: 4),
                            ),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.lock_outline,
                                  color: AppColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text(
                                'SYSTEM LOGIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                BlurValidatedTextField(
                                  key: const Key('email_field'),
                                  controller: _emailController,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address',
                                    prefixIcon: Icon(Icons.email_outlined,
                                        size: 20),
                                  ),
                                  validator: (v) =>
                                      (v == null || !v.contains('@'))
                                          ? 'Enter a valid email'
                                          : null,
                                ),
                                const SizedBox(height: 14),
                                BlurValidatedTextField(
                                  key: const Key('password_field'),
                                  controller: _passwordController,
                                  obscureText: _obscure,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) =>
                                      auth.busy ? null : _submit(),
                                  decoration: InputDecoration(
                                    labelText: 'Password',
                                    prefixIcon: const Icon(
                                        Icons.lock_outlined,
                                        size: 20),
                                    suffixIcon: IconButton(
                                      icon: Icon(_obscure
                                          ? Icons.visibility_off_outlined
                                          : Icons.visibility_outlined),
                                      onPressed: () => setState(
                                          () => _obscure = !_obscure),
                                    ),
                                  ),
                                  validator: (v) => (v == null ||
                                          v.length < 8)
                                      ? 'Password must be at least 8 characters'
                                      : null,
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                        foregroundColor: AppColors.info),
                                    onPressed: () =>
                                        Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const ForgotPasswordScreen(),
                                      ),
                                    ),
                                    child: const Text('Forgot Password?',
                                        style: TextStyle(fontSize: 12)),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                FilledButton(
                                  key: const Key('login_button'),
                                  onPressed: auth.busy ? null : _submit,
                                  child: auth.busy
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.login, size: 18),
                                            SizedBox(width: 8),
                                            Text('SIGN IN TO SYSTEM'),
                                          ],
                                        ),
                                ),
                                if (_showResend) ...[
                                  const SizedBox(height: 12),
                                  _ResendNotice(
                                    busy: _resendBusy,
                                    onResend: _resendVerification,
                                  ),
                                ],
                                const SizedBox(height: 16),
                                const Row(
                                  children: [
                                    Expanded(child: Divider()),
                                    Padding(
                                      padding: EdgeInsets.symmetric(
                                          horizontal: 10),
                                      child: Text('OR',
                                          style: TextStyle(
                                              color: AppColors.textMuted,
                                              fontSize: 12)),
                                    ),
                                    Expanded(child: Divider()),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                OutlinedButton(
                                  onPressed: auth.busy
                                      ? null
                                      : () => Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) =>
                                                  const RegisterScreen(),
                                            ),
                                          ),
                                  child: const Text('CREATE NEW ACCOUNT'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '© 2026 Smart NGO M&E System\n'
                    'University of Eastern Africa, Baraton',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 11, color: AppColors.textMuted, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official green header with the flag ribbon and system identity block.
class _GovernmentHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.primary,
      padding: EdgeInsets.only(top: MediaQuery.paddingOf(context).top),
      child: Column(
        children: [
          const FlagRibbon(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 60,
                  height: 60,
                  color: Colors.white,
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('NGO',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 14,
                                fontWeight: FontWeight.w900,
                                height: 1.2)),
                        Text('M&E',
                            style: TextStyle(
                                color: AppColors.accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                height: 1.2)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SMART NGO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          )),
                      Text('MONITORING & EVALUATION SYSTEM',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10,
                            letterSpacing: 1.0,
                          )),
                      SizedBox(height: 4),
                      Text('University of Eastern Africa, Baraton',
                          style: TextStyle(
                            color: AppColors.accentLight,
                            fontSize: 10,
                            fontStyle: FontStyle.italic,
                          )),
                    ],
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

/// Amber notice shown after an EMAIL_NOT_VERIFIED error, with resend link.
class _ResendNotice extends StatelessWidget {
  final bool busy;
  final VoidCallback onResend;
  const _ResendNotice({required this.busy, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.warningTint,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: AppColors.warning),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.mark_email_unread_outlined,
              size: 20, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please verify your email before signing in.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.warning),
                ),
                GestureDetector(
                  onTap: busy ? null : onResend,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      busy ? 'Sending…' : 'Resend verification email',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                    ),
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
