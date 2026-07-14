import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/constants/app_theme_data.dart';
import '../../../core/theme.dart';
import '../../ngos/ngo_repository.dart';
import '../auth_provider.dart';
import '../models/user.dart';
import 'forgot_password_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  String? _ngoName;
  bool _notificationsEnabled = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveNgoName());
  }

  /// Best-effort: resolve the NGO's display name from the public list
  /// (the authenticated payload only carries the NGO id).
  Future<void> _resolveNgoName() async {
    final ngoId = context.read<AuthProvider>().user?.ngoId;
    if (ngoId == null) return;
    try {
      final ngos = await context.read<NgoRepository>().listPublic();
      final match = ngos.where((n) => n.id == ngoId);
      if (mounted && match.isNotEmpty) {
        setState(() => _ngoName = match.first.name);
      }
    } on ApiException {
      // Leave the name unresolved; the header simply omits it.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: EdgeInsets.zero,
              children: [
                _Header(user: user, ngoName: _ngoName),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Text('ACCOUNT INFORMATION',
                            style: AppTextStyles.capsLabel),
                      ),
                      Card(
                        child: Column(
                          children: [
                            _InfoTile(
                              icon: Icons.email_outlined,
                              label: 'Email',
                              value: user.email,
                            ),
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.phone_outlined,
                              label: 'Phone',
                              value:
                                  user.phone.isEmpty ? 'Not set' : user.phone,
                            ),
                            const Divider(height: 1, indent: 56),
                            _InfoTile(
                              icon: Icons.badge_outlined,
                              label: 'Role',
                              value: user.roleLabel,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Text('SETTINGS',
                            style: AppTextStyles.capsLabel),
                      ),
                      Card(
                        child: Column(
                          children: [
                            ListTile(
                              leading: const Icon(Icons.lock_outline,
                                  color: AppColors.primary),
                              title: const Text('Change Password'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const ForgotPasswordScreen()),
                              ),
                            ),
                            const Divider(height: 1, indent: 56),
                            SwitchListTile(
                              secondary: const Icon(
                                  Icons.notifications_outlined,
                                  color: AppColors.primary),
                              title: const Text('Notifications'),
                              value: _notificationsEnabled,
                              onChanged: (v) =>
                                  setState(() => _notificationsEnabled = v),
                            ),
                            const Divider(height: 1, indent: 56),
                            ListTile(
                              leading: const Icon(Icons.bar_chart_outlined,
                                  color: AppColors.primary),
                              title: const Text('Analytics'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.push('/analytics'),
                            ),
                          ],
                        ),
                      ),
                      if (user.role == 'admin') ...[
                        Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        child: Text('ADMINISTRATION',
                            style: AppTextStyles.capsLabel),
                      ),
                        Card(
                          child: Column(
                            children: [
                              ListTile(
                                leading: const Icon(
                                    Icons.manage_accounts_outlined,
                                    color: AppColors.primary),
                                title: const Text('User Management'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/users'),
                              ),
                              const Divider(height: 1, indent: 56),
                              ListTile(
                                leading: const Icon(Icons.domain_outlined,
                                    color: AppColors.primary),
                                title: const Text('NGO Management'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => context.push('/ngos'),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.logout_outlined,
                              color: AppColors.danger),
                          title: const Text(
                            'Sign Out',
                            style: TextStyle(color: AppColors.danger),
                          ),
                          onTap: () => _confirmLogout(context),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sign out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }
}

class _Header extends StatelessWidget {
  final User user;
  final String? ngoName;
  const _Header({required this.user, required this.ngoName});

  @override
  Widget build(BuildContext context) {
    final initials = [user.firstName, user.lastName]
        .where((s) => s.trim().isNotEmpty)
        .map((s) => s.trim()[0].toUpperCase())
        .join();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: AppThemeData.headerGradient,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
          24, MediaQuery.paddingOf(context).top + 32, 24, 32),
      child: Column(
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.accent,
            child: Text(
              initials.isEmpty ? '?' : initials,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 22, color: Colors.white, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              user.roleLabel,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          if (ngoName != null) ...[
            const SizedBox(height: 8),
            Text(
              ngoName!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
            ),
          ],
          const SizedBox(height: 4),
          Text(
            user.email,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelMedium
            ?.copyWith(color: AppColors.muted),
      ),
      subtitle: Text(value, style: Theme.of(context).textTheme.bodyLarge),
    );
  }
}
