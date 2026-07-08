import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../ngo_repository.dart';

/// Admin-only screen: list all NGOs registered on the platform.
class NgoManagementScreen extends StatefulWidget {
  const NgoManagementScreen({super.key});

  @override
  State<NgoManagementScreen> createState() => _NgoManagementScreenState();
}

class _NgoManagementScreenState extends State<NgoManagementScreen> {
  late Future<List<Ngo>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<NgoRepository>().list().then((p) => p.results);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('NGO Management')),
      body: FutureBuilder<List<Ngo>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return _ShimmerList();
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: AppColors.muted),
                  const SizedBox(height: 12),
                  const Text('Failed to load NGOs.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                      onPressed: () => setState(_load),
                      child: const Text('Retry')),
                ],
              ),
            );
          }
          final ngos = snap.data ?? [];
          if (ngos.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.domain_outlined,
                      size: 52,
                      color: Theme.of(context).colorScheme.outlineVariant),
                  const SizedBox(height: 12),
                  const Text('No NGOs registered yet.'),
                ],
              ),
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.domain_outlined,
                      color: AppColors.primary, size: 22),
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
              ],
            ),
            if (ngo.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              const Divider(height: 1),
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
              const SizedBox(height: 8),
              Row(
                children: [
                  if (ngo.contact.isNotEmpty)
                    _Meta(Icons.phone_outlined, ngo.contact),
                  if (ngo.contact.isNotEmpty && ngo.address.isNotEmpty)
                    const SizedBox(width: 16),
                  if (ngo.address.isNotEmpty)
                    _Meta(Icons.location_on_outlined, ngo.address),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String value;
  const _Meta(this.icon, this.value);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 4),
        Text(value,
            style: Theme.of(context)
                .textTheme
                .labelSmall
                ?.copyWith(color: AppColors.muted)),
      ],
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
        padding: const EdgeInsets.all(16),
        itemCount: 5,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (_, _) => Container(
          height: 90,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
    );
  }
}
