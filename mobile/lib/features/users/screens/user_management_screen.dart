import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
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
      builder: (_) => const _UserFormSheet(),
    );
    if (created == true && mounted) setState(_load);
  }

  Future<void> _editUser(ManagedUser user) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserFormSheet(existing: user),
    );
    if (saved == true && mounted) setState(_load);
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
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
                            color: _roleFilter == entry.key
                                ? Colors.white
                                : null,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: users.isEmpty
                    ? const EmptyState(
                        Icons.person_search_outlined,
                        'No users',
                        'No users match this filter.',
                      )
                    : RefreshIndicator(
                        onRefresh: () async => setState(_load),
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                          itemCount: users.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, i) => _UserCard(
                            user: users[i],
                            onToggled: () => setState(_load),
                            onEdit: () => _editUser(users[i]),
                          ),
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
              Text(
                '$value',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: AppColors.muted),
              ),
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
  final VoidCallback onEdit;
  const _UserCard({
    required this.user,
    required this.onToggled,
    required this.onEdit,
  });

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
      showErrorSnackBar(context, 'Failed: $e');
    } finally {
      if (mounted) setState(() => _toggling = false);
    }
  }

  /// Avatar tint by role: admin=red, manager=green, officer=amber,
  /// donor=blue.
  Color get _roleColor => switch (widget.user.role) {
    'admin' => AppColors.danger,
    'manager' => AppColors.success,
    'officer' => AppColors.accent,
    'donor' => AppColors.info,
    _ => AppColors.neutral,
  };

  @override
  Widget build(BuildContext context) {
    final u = widget.user;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onEdit,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _roleColor.withValues(alpha: 0.14),
                child: Text(
                  u.fullName.isNotEmpty ? u.fullName[0].toUpperCase() : '?',
                  style: TextStyle(
                    color: _roleColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.fullName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      u.email,
                      style: Theme.of(
                        context,
                      ).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                    ),
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
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Switch(value: u.isActive, onChanged: (_) => _toggle()),
            ],
          ),
        ),
      ),
    );
  }
}

/// Bottom sheet form used for both creating a user and editing an existing
/// one. In create mode it collects email + a temporary password; in edit mode
/// email is shown read-only (it is the login identity) and the password field
/// is dropped — passwords go through the reset flow — while phone becomes
/// editable.
class _UserFormSheet extends StatefulWidget {
  final ManagedUser? existing;
  const _UserFormSheet({this.existing});

  @override
  State<_UserFormSheet> createState() => _UserFormSheetState();
}

class _UserFormSheetState extends State<_UserFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _firstName;
  late final TextEditingController _lastName;
  late final TextEditingController _phone;
  final _email = TextEditingController();
  final _password = TextEditingController();
  late String _role;
  bool _busy = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final u = widget.existing;
    _firstName = TextEditingController(text: u?.firstName ?? '');
    _lastName = TextEditingController(text: u?.lastName ?? '');
    _phone = TextEditingController(text: u?.phone ?? '');
    _role = u?.role ?? 'officer';
  }

  @override
  void dispose() {
    _firstName.dispose();
    _lastName.dispose();
    _phone.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  /// Role options offered in the picker. Admins cannot be minted or promoted
  /// to here, so "admin" appears only to keep an existing admin's row valid.
  List<DropdownMenuItem<String>> get _roleItems {
    final items = <DropdownMenuItem<String>>[
      if (_isEdit && widget.existing!.role == 'admin')
        const DropdownMenuItem(value: 'admin', child: Text('Administrator')),
      const DropdownMenuItem(value: 'manager', child: Text('Manager')),
      const DropdownMenuItem(value: 'officer', child: Text('Officer')),
      const DropdownMenuItem(value: 'donor', child: Text('Donor')),
    ];
    return items;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final repo = context.read<UserRepository>();
      if (_isEdit) {
        await repo.update(
          id: widget.existing!.id,
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          role: _role,
          phone: _phone.text.trim(),
        );
      } else {
        await repo.create(
          firstName: _firstName.text.trim(),
          lastName: _lastName.text.trim(),
          email: _email.text.trim(),
          password: _password.text,
          role: _role,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        showErrorSnackBar(context, e.message);
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
            Text(
              _isEdit ? 'Edit User' : 'Add User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _firstName,
                    decoration: const InputDecoration(labelText: 'First name'),
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
            if (_isEdit)
              // Email is the login identity — shown for reference, not edited.
              TextFormField(
                initialValue: widget.existing!.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  helperText: "Email can't be changed here.",
                ),
              )
            else
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
            const SizedBox(height: 12),
            if (_isEdit)
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  hintText: 'Optional',
                ),
              )
            else
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Temporary password',
                ),
                validator: (v) => (v == null || v.length < 8)
                    ? 'At least 8 characters'
                    : null,
              ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _role,
              decoration: const InputDecoration(labelText: 'Role'),
              items: _roleItems,
              onChanged: (v) => setState(() => _role = v ?? _role),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, false),
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
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isEdit ? 'Save Changes' : 'Create'),
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
