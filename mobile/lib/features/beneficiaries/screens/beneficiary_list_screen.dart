import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../auth/auth_provider.dart';
import '../beneficiary_repository.dart';
import '../models/beneficiary.dart';
import 'register_beneficiary_screen.dart';

class BeneficiaryListScreen extends StatefulWidget {
  /// Optional project filter (when opened from a project).
  final int? projectId;

  const BeneficiaryListScreen({super.key, this.projectId});

  @override
  State<BeneficiaryListScreen> createState() => _BeneficiaryListScreenState();
}

class _BeneficiaryListScreenState extends State<BeneficiaryListScreen> {
  late Future<List<Beneficiary>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<BeneficiaryRepository>();
    _future =
        repo.list(projectId: widget.projectId).then((p) => p.results);
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
      appBar: AppBar(title: const Text('Beneficiaries')),
      floatingActionButton: canRegister
          ? FloatingActionButton.extended(
              onPressed: _register,
              icon: const Icon(Icons.person_add),
              label: const Text('Register'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Beneficiary>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              final err = snapshot.error;
              return Center(
                child: Text(err is ApiException ? err.message : 'Failed.'),
              );
            }
            final items = snapshot.data ?? const [];
            if (items.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No beneficiaries yet.')),
                ],
              );
            }
            return ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final b = items[i];
                return ListTile(
                  leading: CircleAvatar(child: Text(_initial(b.name))),
                  title: Text(b.name),
                  subtitle: Text([
                    if (b.age != null) 'Age ${b.age}',
                    b.gender,
                    if (b.location.isNotEmpty) b.location,
                  ].join(' • ')),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _initial(String name) =>
      name.isEmpty ? '?' : name.trim()[0].toUpperCase();
}
