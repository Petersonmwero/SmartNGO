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

/// Official beneficiary register: green summary bar, filter bar, and an
/// alternating table (NAME | AGE | STATUS) in eCitizen style.
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

  static const _genders = <String?, String>{
    null: 'All genders',
    'female': 'Female',
    'male': 'Male',
  };

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
            b.fullLocation.toLowerCase().contains(q))
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
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('BENEFICIARY REGISTER'),
      ),
      floatingActionButton: canRegister
          ? FloatingActionButton(
              tooltip: 'Register beneficiary',
              onPressed: _register,
              child: const Icon(Icons.person_add_outlined),
            )
          : null,
      body: Column(
        children: [
          // Green summary statistics bar.
          Container(
            color: AppColors.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _HeaderStat('Total', _total),
                Container(width: 1, height: 30, color: Colors.white24),
                _HeaderStat('Female', _female),
                Container(width: 1, height: 30, color: Colors.white24),
                _HeaderStat('Male', _male),
              ],
            ),
          ),
          // Official filter bar.
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Search by name...',
                      prefixIcon: Icon(Icons.search,
                          color: AppColors.primary, size: 20),
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                          vertical: 8, horizontal: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                PopupMenuButton<String?>(
                  tooltip: 'Filter by gender',
                  onSelected: (v) => setState(() {
                    _gender = v == '__all__' ? null : v;
                    _load();
                  }),
                  itemBuilder: (_) => [
                    for (final e in _genders.entries)
                      PopupMenuItem(
                        value: e.key ?? '__all__',
                        child: Text(e.value),
                      ),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 10),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.primary),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_list,
                            color: AppColors.primary, size: 18),
                        const SizedBox(width: 4),
                        Text(
                          _gender == null ? 'Filter' : _genders[_gender]!,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table header.
          Container(
            color: AppColors.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: const Row(
              children: [
                Expanded(flex: 4, child: Text('NAME', style: _headerStyle)),
                Expanded(flex: 1, child: Text('AGE', style: _headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text('STATUS',
                        style: _headerStyle, textAlign: TextAlign.end)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => setState(_load),
              child: FutureBuilder<List<Beneficiary>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(itemCount: 6, cardHeight: 56);
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
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _BeneficiaryTableRow(
                      beneficiary: filtered[i],
                      even: i.isEven,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  static const _headerStyle = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
  );
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
            style: const TextStyle(
                color: AppColors.accentLight,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          Text(label,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Alternating register row: name + location/project, computed age, status.
class _BeneficiaryTableRow extends StatelessWidget {
  final Beneficiary beneficiary;
  final bool even;
  const _BeneficiaryTableRow({required this.beneficiary, required this.even});

  @override
  Widget build(BuildContext context) {
    final b = beneficiary;
    final meta = [
      if (b.locationSummary.isNotEmpty) b.locationSummary,
      if (b.projectName.isNotEmpty) b.projectName,
    ].join(' — ');

    return Container(
      color: even ? Colors.white : AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  b.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                if (meta.isNotEmpty)
                  Text(
                    meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 11, color: AppColors.textMuted),
                  ),
              ],
            ),
          ),
          Expanded(
            flex: 1,
            child: Text(
              b.age?.toString() ?? '—',
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerRight,
              child: StatusBadge(b.isActive ? 'active' : 'inactive'),
            ),
          ),
        ],
      ),
    );
  }
}
