import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<BeneficiaryRepository>();
    _future = repo.list(projectId: widget.projectId).then((p) => p.results);
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
        builder: (_) =>
            RegisterBeneficiaryScreen(projectId: widget.projectId),
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
        title: const Text('Beneficiaries'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search by name or location…',
                hintStyle:
                    TextStyle(color: Colors.white.withValues(alpha: 0.6)),
                prefixIcon: Icon(Icons.search,
                    color: Colors.white.withValues(alpha: 0.7)),
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: Colors.white, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: canRegister
          ? FloatingActionButton.extended(
              onPressed: _register,
              icon: const Icon(Icons.person_add_outlined),
              label: const Text('Register'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Beneficiary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _ShimmerList();
            }
            if (snapshot.hasError) {
              final err = snapshot.error;
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline,
                        size: 48,
                        color: Theme.of(context).colorScheme.outlineVariant),
                    const SizedBox(height: 12),
                    Text(err is ApiException ? err.message : 'Failed to load.',
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              );
            }
            final filtered = _filtered(snapshot.data ?? []);
            if (filtered.isEmpty) {
              return _EmptyState(canRegister: canRegister, onRegister: _register);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
              itemCount: filtered.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _BeneficiaryCard(filtered[i]),
            );
          },
        ),
      ),
    );
  }
}

class _BeneficiaryCard extends StatelessWidget {
  final Beneficiary b;
  const _BeneficiaryCard(this.b);

  @override
  Widget build(BuildContext context) {
    final initial = b.name.trim().isNotEmpty ? b.name.trim()[0].toUpperCase() : '?';
    final meta = [
      if (b.age != null) 'Age ${b.age}',
      b.gender,
      if (b.location.isNotEmpty) b.location,
    ].join(' · ');

    return Card(
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: AppColors.secondary.withValues(alpha: 0.2),
          child: Text(
            initial,
            style: const TextStyle(
                color: AppColors.statusActive, fontWeight: FontWeight.w700),
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
      ),
    );
  }
}

class _ShimmerList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
        itemCount: 7,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool canRegister;
  final VoidCallback onRegister;
  const _EmptyState({required this.canRegister, required this.onRegister});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 16),
          Text('No beneficiaries yet',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            canRegister
                ? 'Tap "Register" to add the first beneficiary.'
                : 'No beneficiaries have been registered yet.',
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
