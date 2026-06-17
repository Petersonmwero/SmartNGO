import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../models/project.dart';
import '../project_repository.dart';
import 'project_detail_screen.dart';

class ProjectsListScreen extends StatefulWidget {
  const ProjectsListScreen({super.key});

  @override
  State<ProjectsListScreen> createState() => _ProjectsListScreenState();
}

class _ProjectsListScreenState extends State<ProjectsListScreen> {
  late Future<List<Project>> _future;
  String? _status;

  static const _statuses = {
    null: 'All',
    'planning': 'Planning',
    'active': 'Active',
    'on_hold': 'On Hold',
    'completed': 'Completed',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<ProjectRepository>();
    _future = repo.list(status: _status).then((p) => p.results);
  }

  void _selectStatus(String? status) {
    setState(() {
      _status = status;
      _load();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      body: Column(
        children: [
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final entry in _statuses.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 10),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) => _selectStatus(entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => setState(_load),
              child: FutureBuilder<List<Project>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    final err = snapshot.error;
                    final msg =
                        err is ApiException ? err.message : 'Failed to load.';
                    return _CenteredMessage(msg, onRetry: () => setState(_load));
                  }
                  final projects = snapshot.data ?? const [];
                  if (projects.isEmpty) {
                    return const _CenteredMessage('No projects found.');
                  }
                  return ListView.separated(
                    itemCount: projects.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = projects[i];
                      return ListTile(
                        title: Text(p.projectName),
                        subtitle: Text('Budget: ${p.budget}'),
                        trailing: Chip(
                          label: Text(p.statusLabel),
                          backgroundColor: p.statusColor.withValues(alpha: 0.15),
                          side: BorderSide(color: p.statusColor),
                        ),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProjectDetailScreen(
                                projectId: p.id, title: p.projectName),
                          ),
                        ),
                      );
                    },
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

class _CenteredMessage extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const _CenteredMessage(this.message, {this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
