import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../auth_provider.dart';
import '../models/user.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: user == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _Header(user: user),
                const SizedBox(height: 8),
                _InfoTile(
                  icon: Icons.email_outlined,
                  label: 'Email',
                  value: user.email,
                ),
                _InfoTile(
                  icon: Icons.badge_outlined,
                  label: 'Role',
                  value: user.roleLabel,
                ),
                if (user.ngoId != null)
                  _InfoTile(
                    icon: Icons.business_outlined,
                    label: 'NGO ID',
                    value: user.ngoId.toString(),
                  ),
                const Divider(height: 32),
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined,
                      color: AppColors.primary),
                  title: const Text('Analytics'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/analytics'),
                ),
                if (user.role == 'admin') ...[
                  ListTile(
                    leading: const Icon(Icons.people_outlined,
                        color: AppColors.primary),
                    title: const Text('User Management'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/users'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.domain_outlined,
                        color: AppColors.primary),
                    title: const Text('NGO Management'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/ngos'),
                  ),
                ],
                const Divider(height: 32),
                ListTile(
                  leading:
                      const Icon(Icons.logout_outlined, color: Color(0xFFC62828)),
                  title: const Text(
                    'Sign out',
                    style: TextStyle(color: Color(0xFFC62828)),
                  ),
                  onTap: () => _confirmLogout(context),
                ),
                const SizedBox(height: 24),
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
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
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
  const _Header({required this.user});

  @override
  Widget build(BuildContext context) {
    final initial =
        user.fullName.trim().isNotEmpty ? user.fullName.trim()[0].toUpperCase() : '?';

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
      child: Column(
        children: [
          CircleAvatar(
            radius: 42,
            backgroundColor: Colors.white.withValues(alpha: 0.18),
            child: Text(
              initial,
              style: Theme.of(context)
                  .textTheme
                  .headlineMedium
                  ?.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            user.fullName,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              user.roleLabel,
              style: Theme.of(context)
                  .textTheme
                  .labelMedium
                  ?.copyWith(color: Colors.white),
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
