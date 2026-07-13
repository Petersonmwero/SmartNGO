import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../user_repository.dart';

/// Admin-only screen: list, filter, create, and activate/deactivate users.
class UserManagementScreen extends StatefulWidget {
  const UserManagementScreen({super.key});

  @override
  State<UserManagementScreen> createState() => _UserManagementScreenState();
}

class _UserManagementScreenState extends State<UserManagementScreen> {
  late Future<List<ManagedUser>> _future;
  String? _roleFilter;

  static const _roles = <String?, String>{
    null: 'All',
    'admin': 'Admin',
    'manager': 'Manager',
    'officer': 'Officer',
    'donor': 'Donor',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<UserRepository>().list().then((p) => p.results);
  }

  Future<void> _createUser() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateUserSheet(),
    );
    if (created == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('User Management'),
        actions: [
          IconButton(
            tooltip: 'Add user',
            icon: const Icon(Icons.add),
            onPressed: _createUser,
          ),
        ],
      ),
      body: FutureBuilder<List<ManagedUser>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerList(cardHeight: 84);
          }
          if (snap.hasError) {
            return EmptyState(
              Icons.cloud_off_outlined,
              'Something went wrong',
              'Failed to load users.',
              buttonLabel: 'Retry',
              onButton: () => setState(_load),
            );
          }
          final all = snap.data ?? [];
          final active = all.where((u) => u.isActive).length;
          final users = _roleFilter == null
              ? all
              : all.where((u) => u.role == _roleFilter).toList();

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Row(
                  children: [
                    _StatTile('Total Users', all.length),
                    const SizedBox(width: 12),
                    _StatTile('Active', active),
                    const SizedBox(width: 12),
                    _StatTile('Inactive', all.length - active),
                  ],
                ),
              ),
              SizedBox(
                height: 52,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  children: [
                    for (final entry in _roles.entries)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.value),
                          selected: _roleFilter == entry.key,
                          onSelected: (_) =>
                              setState(() => _roleFilter = entry.key),
                          selectedColor: AppColors.primary,
                          labelStyle: TextStyle(
                            color:
                                _roleFilter == entry.key ? Colors.white : null,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(Icons.person_search_outlined,
                        'No users', 'No users match this filter.')
                    : RefreshIndicator(
                        onRefresh: () async => setState(_load),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _UserCard(
                              user: users[i],
                              onToggled: () => setState(_load)),
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int value;
  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text('$value',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                      )),
              Text(label,
                  style: Theme.of(context)
                      .textTheme
                      .labelSmall
                      ?.copyWith(color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}

class _UserCard extends StatefulWidget {
  final ManagedUser user;
  final VoidCallback onToggled;
  const _UserCard({required this.user, required this.onToggled});

  @override
  State<_UserCard> createState() => _UserCardState();
}

class _UserCardState extends State<_UserCard> {
  bool _toggling = false;

  Future<void> _toggle() async {
    setState(() => _toggling = true);
    try {
      await context.read<UserRepository>().toggleActive(widget.user.id);
      widget.onToggled();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                style: const TextStyle(
                    color: AppColors.primary, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.fullName,
                      style: Theme.of(context).textTheme.titleSmall),
                  Text(u.email,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    children: [
                      StatusBadge('completed', label: u.roleLabel),
                      if (!u.isActive) const StatusBadge('inactive'),
                    ],
                  ),
                ],
              ),
            ),
            _toggling
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : Switch(
                    value: u.isActive,
                    onChanged: (_) => _toggle(),
                  ),
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet form for creating a new user in the admin's NGO.
class _CreateUserSheet extends StatefulWidget {
  const _CreateUserSheet();

  @override
  State<_CreateUserSheet> createState() => _CreateUserSheetState();
}

class _CreateUserSheetState extends State<_CreateUserSheet> {
  final _formKey = GlobalKey<FormState>();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  String _role = 'officer';
  bool _busy = false;

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<UserRepository>().create(
            firstName: _firstName.text.trim(),
            lastName: _lastName.text.trim(),
            email: _email.text.trim(),
            password: _password.text,
            role: _role,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Add User', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    decoration:
                        const InputDecoration(labelText: 'First name'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _lastName,
                    decoration: const InputDecoration(labelText: 'Last name'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null || !v.contains('@'))
                  ? 'Enter a valid email'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _password,
              obscureText: true,
              decoration:
                  const InputDecoration(labelText: 'Temporary password'),
              validator: (v) => (v == null || v.length < 8)
                  ? 'At least 8 characters'
                  : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: const [
                DropdownMenuItem(value: 'manager', child: Text('Manager')),
                DropdownMenuItem(value: 'officer', child: Text('Officer')),
                DropdownMenuItem(value: 'donor', child: Text('Donor')),
              ],
              onChanged: (v) => setState(() => _role = v ?? 'officer'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed:
                        _busy ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Text('Create'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
