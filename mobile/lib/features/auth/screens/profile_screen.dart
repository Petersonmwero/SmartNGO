import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/official_card.dart';
import '../../ngos/ngo_repository.dart';
import '../auth_provider.dart';
import 'forgot_password_screen.dart';

/// Official account page: compact green identity header plus table-style
/// ACCOUNT INFORMATION / SECURITY SETTINGS / SYSTEM ACTIONS cards.
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
      // Leave the name unresolved; the row shows a dash.
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('MY ACCOUNT'),
      ),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _IdentityHeader(
                  fullName: user.fullName,
                  roleLabel: user.roleLabel,
                  email: user.email,
                ),
                OfficialCard(
                  title: 'Account Information',
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                  child: Column(
                    children: [
                      InfoRow('Full Name', user.fullName),
                      InfoRow('Email', user.email),
                      InfoRow('Phone',
                          user.phone.isEmpty ? 'Not set' : user.phone),
                      InfoRow('Role', user.roleLabel),
                      InfoRow('Organisation', _ngoName ?? '—'),
                      const InfoRow('Account Status', 'Active ✓'),
                    ],
                  ),
                ),
                OfficialCard(
                  title: 'Security & Settings',
                  contentPadding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.lock_outline,
                            color: AppColors.primary, size: 20),
                        title: const Text('Change Password'),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ForgotPasswordScreen()),
                        ),
                      ),
                      const Divider(height: 1, indent: 52),
                      SwitchListTile(
                        dense: true,
                        secondary: const Icon(Icons.notifications_outlined,
                            color: AppColors.primary, size: 20),
                        title: const Text('Notifications'),
                        activeThumbColor: AppColors.primary,
                        value: _notificationsEnabled,
                        onChanged: (v) =>
                            setState(() => _notificationsEnabled = v),
                      ),
                      const Divider(height: 1, indent: 52),
                      ListTile(
                        dense: true,
                        leading: const Icon(Icons.bar_chart_outlined,
                            color: AppColors.primary, size: 20),
                        title: const Text('Analytics'),
                        trailing: const Icon(Icons.chevron_right,
                            color: AppColors.textMuted),
                        onTap: () => context.push('/analytics'),
                      ),
                    ],
                  ),
                ),
                if (user.role == 'admin')
                  OfficialCard(
                    title: 'Administration',
                    contentPadding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        ListTile(
                          dense: true,
                          leading: const Icon(
                              Icons.manage_accounts_outlined,
                              color: AppColors.primary,
                              size: 20),
                          title: const Text('User Management'),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                          onTap: () => context.push('/users'),
                        ),
                        const Divider(height: 1, indent: 52),
                        ListTile(
                          dense: true,
                          leading: const Icon(Icons.domain_outlined,
                              color: AppColors.primary, size: 20),
                          title: const Text('NGO Management'),
                          trailing: const Icon(Icons.chevron_right,
                              color: AppColors.textMuted),
                          onTap: () => context.push('/ngos'),
                        ),
                      ],
                    ),
                  ),
                OfficialCard(
                  title: 'System Actions',
                  ruleColor: AppColors.error,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(
                          color: AppColors.error, width: 1.5),
                    ),
                    onPressed: () => _confirmLogout(context),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.logout, size: 16),
                        SizedBox(width: 8),
                        Text('SIGN OUT OF SYSTEM'),
                      ],
                    ),
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
            style: FilledButton.styleFrom(backgroundColor: AppColors.error),
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

/// Compact identity strip below the AppBar: gold avatar, name, role badge.
class _IdentityHeader extends StatelessWidget {
  final String fullName;
  final String roleLabel;
  final String email;

  const _IdentityHeader({
    required this.fullName,
    required this.roleLabel,
    required this.email,
  });

  @override
  Widget build(BuildContext context) {
    final initials = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .take(2)
        .map((s) => s[0].toUpperCase())
        .join();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.accent,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white30, width: 1.5),
            ),
            child: Center(
              child: Text(
                initials.isEmpty ? '?' : initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fullName,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(email,
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              roleLabel.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
