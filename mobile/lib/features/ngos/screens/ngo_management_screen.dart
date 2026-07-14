import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/feedback.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../ngo_repository.dart';

/// Admin-only screen: list and register NGOs on the platform.
class NgoManagementScreen extends StatefulWidget {
  const NgoManagementScreen({super.key});

  @override
  State<NgoManagementScreen> createState() => _NgoManagementScreenState();
}

class _NgoManagementScreenState extends State<NgoManagementScreen> {
  late Future<List<Ngo>> _future;
  int? _count;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<NgoRepository>().list().then((p) {
      if (mounted) setState(() => _count = p.count);
      return p.results;
    });
  }

  Future<void> _createNgo() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CreateNgoSheet(),
    );
    if (created == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('NGO Management'),
            if (_count != null)
              Text(
                '$_count NGO${_count == 1 ? '' : 's'} registered',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Register NGO',
            icon: const Icon(Icons.add),
            onPressed: _createNgo,
          ),
        ],
      ),
      body: FutureBuilder<List<Ngo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerList(cardHeight: 96);
          }
          if (snap.hasError) {
            return EmptyState(
              Icons.cloud_off_outlined,
              'Something went wrong',
              'Failed to load NGOs.',
              buttonLabel: 'Retry',
              onButton: () => setState(_load),
            );
          }
          final ngos = snap.data ?? [];
          if (ngos.isEmpty) {
            return EmptyState(
              Icons.domain_outlined,
              'No NGOs',
              'Register the first NGO to get started.',
              buttonLabel: 'Register NGO',
              onButton: _createNgo,
            );
          }
          return RefreshIndicator(
            onRefresh: () async => setState(_load),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: ngos.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => _NgoCard(ngo: ngos[i]),
            ),
          );
        },
      ),
    );
  }
}

class _NgoCard extends StatelessWidget {
  final Ngo ngo;
  const _NgoCard({required this.ngo});

  /// Initials from the first letters of up to two words of the name.
  String get _initials => ngo.name
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    _initials.isEmpty ? '?' : _initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(ngo.name,
                          style: Theme.of(context).textTheme.titleSmall),
                      Text(ngo.registrationNo,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.muted)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right, color: AppColors.muted),
              ],
            ),
            if (ngo.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(ngo.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (ngo.contact.isNotEmpty || ngo.address.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  if (ngo.contact.isNotEmpty)
                    InfoChip(Icons.phone_outlined, ngo.contact),
                  if (ngo.address.isNotEmpty)
                    InfoChip(Icons.location_on_outlined, ngo.address),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Bottom sheet form for registering a new NGO.
class _CreateNgoSheet extends StatefulWidget {
  const _CreateNgoSheet();

  @override
  State<_CreateNgoSheet> createState() => _CreateNgoSheetState();
}

class _CreateNgoSheetState extends State<_CreateNgoSheet> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _regNo = TextEditingController();
  final _address = TextEditingController();
  final _contact = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _regNo.dispose();
    _address.dispose();
    _contact.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await context.read<NgoRepository>().create(
            name: _name.text.trim(),
            registrationNo: _regNo.text.trim(),
            address: _address.text.trim(),
            contact: _contact.text.trim(),
          );
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
            Text('Register NGO', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'NGO name'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _regNo,
              decoration:
                  const InputDecoration(labelText: 'Registration number'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _address,
              decoration:
                  const InputDecoration(labelText: 'Address (optional)'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _contact,
              decoration:
                  const InputDecoration(labelText: 'Contact (optional)'),
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
                        : const Text('Register'),
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
