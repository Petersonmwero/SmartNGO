import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/constants/app_theme_data.dart';
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
      floatingActionButton: canRegister
          ? FloatingActionButton(
              tooltip: 'Register beneficiary',
              onPressed: _register,
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: Column(
        children: [
          // Green gradient header holding the title and the stats strip.
          Container(
            width: double.infinity,
            decoration:
                const BoxDecoration(gradient: AppThemeData.headerGradient),
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.paddingOf(context).top + 16, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Beneficiaries',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        color: Colors.white,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      _HeaderStat('Total', _total),
                      Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.3)),
                      _HeaderStat('Female', _female),
                      Container(
                          width: 1,
                          height: 32,
                          color: Colors.white.withValues(alpha: 0.3)),
                      _HeaderStat('Male', _male),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Search bar overlapping the green header.
          Transform.translate(
            offset: const Offset(0, -14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: AppThemeData.cardDecoration,
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search by name…',
                    prefixIcon:
                        const Icon(Icons.search, color: AppColors.primary),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          ),
          // Gender filter chips.
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
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
                    return const ShimmerList(itemCount: 5, cardHeight: 80);
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

class _HeaderStat extends StatelessWidget {
  final String label;
  final int? value;
  const _HeaderStat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value?.toString() ?? '—',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  color: AppColors.accentLight,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.8),
                  )),
        ],
      ),
    );
  }
}

class _BeneficiaryCard extends StatelessWidget {
  final Beneficiary b;
  const _BeneficiaryCard(this.b);

  /// Spec avatar palette: female = amber bg with dark initials, male =
  /// green bg with white initials, other = neutral.
  (Color, Color) get _avatarColors => switch (b.gender) {
        'female' => (AppColors.accent, Colors.white),
        'male' => (AppColors.primary, Colors.white),
        _ => (AppColors.neutralTint, AppColors.neutral),
      };

  @override
  Widget build(BuildContext context) {
    final initial =
        b.name.trim().isNotEmpty ? b.name.trim()[0].toUpperCase() : '?';
    final (avatarBg, avatarFg) = _avatarColors;

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          radius: 24,
          backgroundColor: avatarBg,
          child: Text(
            initial,
            style: TextStyle(color: avatarFg, fontWeight: FontWeight.w700),
          ),
        ),
        title: Text(b.name, style: Theme.of(context).textTheme.titleSmall),
        subtitle: (b.location.isEmpty && b.projectName.isEmpty)
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (b.location.isNotEmpty)
                    Text(b.location,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.muted)),
                  if (b.projectName.isNotEmpty)
                    Text(b.projectName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                                fontSize: 11, color: AppColors.muted)),
                ],
              ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (b.age != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.neutralTint.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text('Age ${b.age}',
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(fontSize: 11, color: AppColors.muted)),
              ),
            const SizedBox(height: 4),
            StatusBadge(b.isActive ? 'active' : 'inactive'),
          ],
        ),
      ),
    );
  }
}
