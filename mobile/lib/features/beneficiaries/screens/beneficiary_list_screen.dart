import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
import '../beneficiary_repository.dart';
import '../models/beneficiary.dart';
import 'register_beneficiary_screen.dart';

class BeneficiaryListScreen extends StatefulWidget {
  final int? projectId;

  const BeneficiaryListScreen({super.key, this.projectId});

  @override
  State<BeneficiaryListScreen> createState() => _BeneficiaryListScreenState();
}

class _BeneficiaryListScreenState extends State<BeneficiaryListScreen> {
  late Future<List<Beneficiary>> _future;
  String _search = '';
  String? _gender;
  int? _total;
  int? _female;
  int? _male;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<BeneficiaryRepository>();
    _future = repo
        .list(projectId: widget.projectId, gender: _gender)
        .then((p) => p.results);
    _loadStats();
  }

  Future<void> _loadStats() async {
    final repo = context.read<BeneficiaryRepository>();
    try {
      final total = await repo.count(projectId: widget.projectId);
      final female =
          await repo.count(projectId: widget.projectId, gender: 'female');
      final male =
          await repo.count(projectId: widget.projectId, gender: 'male');
      if (!mounted) return;
      setState(() {
        _total = total;
        _female = female;
        _male = male;
      });
    } catch (_) {}
  }

  List<Beneficiary> _filtered(List<Beneficiary> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all
        .where((b) =>
            b.name.toLowerCase().contains(q) ||
            b.location.toLowerCase().contains(q))
        .toList();
  }

  Future<void> _register() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => RegisterBeneficiaryScreen(projectId: widget.projectId),
      ),
    );
    if (created == true) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canRegister =
        role == 'officer' || role == 'manager' || role == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Beneficiaries')),
      floatingActionButton: canRegister
          ? FloatingActionButton(
              tooltip: 'Register beneficiary',
              onPressed: _register,
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: Column(
        children: [
          // Stats row.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Row(
              children: [
                _StatTile('Total', _total),
                const SizedBox(width: 12),
                _StatTile('Female', _female),
                const SizedBox(width: 12),
                _StatTile('Male', _male),
              ],
            ),
          ),
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              decoration: const InputDecoration(
                hintText: 'Search by name…',
                prefixIcon: Icon(Icons.search),
                isDense: true,
              ),
            ),
          ),
          // Gender filter chips.
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final entry in const {
                  null: 'All',
                  'female': 'Female',
                  'male': 'Male',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _gender == entry.key,
                      onSelected: (_) => setState(() {
                        _gender = entry.key;
                        _load();
                      }),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _gender == entry.key ? Colors.white : null,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: FutureBuilder<List<Beneficiary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(cardHeight: 80);
                  }
                  if (snapshot.hasError) {
                    final err = snapshot.error;
                    return EmptyState(
                      Icons.cloud_off_outlined,
                      'Something went wrong',
                      err is ApiException ? err.message : 'Failed to load.',
                      buttonLabel: 'Retry',
                      onButton: () => setState(_load),
                    );
                  }
                  final filtered = _filtered(snapshot.data ?? []);
                  if (filtered.isEmpty) {
                    return EmptyState(
                      Icons.people_outline,
                      'No beneficiaries',
                      canRegister
                          ? 'Register the first beneficiary to get started.'
                          : 'No beneficiaries have been registered yet.',
                      buttonLabel:
                          canRegister ? 'Register Beneficiary' : null,
                      onButton: canRegister ? _register : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, i) => _BeneficiaryCard(filtered[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final int? value;
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
                value?.toString() ?? '—',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.accent,
                      fontWeight: FontWeight.w700,
                    ),
              ),
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

class _BeneficiaryCard extends StatelessWidget {
  final Beneficiary b;
  const _BeneficiaryCard(this.b);

  Color get _avatarColor => switch (b.gender) {
        'female' => AppColors.success,
        'male' => AppColors.info,
        _ => AppColors.neutral,
      };

  @override
  Widget build(BuildContext context) {
    final initial =
        b.name.trim().isNotEmpty ? b.name.trim()[0].toUpperCase() : '?';
    final meta = [
      if (b.age != null) 'Age ${b.age}',
      if (b.location.isNotEmpty) b.location,
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: _avatarColor.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(color: _avatarColor, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(b.name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: meta.isNotEmpty
            ? Text(meta,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted))
            : null,
        trailing: StatusBadge(b.isActive ? 'active' : 'inactive'),
      ),
    );
  }
}
