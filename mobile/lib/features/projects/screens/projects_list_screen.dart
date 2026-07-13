import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/info_chip.dart';
import '../../../shared/widgets/project_progress_bar.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
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
  String _search = '';
  int? _count;

  static const _statuses = <String?, String>{
    null: 'All',
    'planning': 'Planning',
    'active': 'Active',
    'on_hold': 'On Hold',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final repo = context.read<ProjectRepository>();
    _future = repo.list(status: _status).then((p) {
      if (mounted) setState(() => _count = p.count);
      return p.results;
    });
  }

  List<Project> _filtered(List<Project> all) {
    final q = _search.trim().toLowerCase();
    if (q.isEmpty) return all;
    return all.where((p) => p.projectName.toLowerCase().contains(q)).toList();
  }

  Future<void> _create() async {
    final created = await context.push<bool>('/projects/new');
    if (created == true && mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canCreate = role == 'manager' || role == 'admin';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Projects'),
            if (_count != null)
              Text(
                '$_count project${_count == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
              ),
          ],
        ),
        actions: [
          if (canCreate)
            IconButton(
              tooltip: 'New project',
              icon: const Icon(Icons.add),
              onPressed: _create,
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (v) => setState(() => _search = v),
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Search projects…',
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
                  borderSide: const BorderSide(color: Colors.white, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: canCreate
          ? FloatingActionButton(
              tooltip: 'New project',
              onPressed: _create,
              child: const Icon(Icons.add),
            )
          : null,
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                for (final entry in _statuses.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _status == entry.key,
                      onSelected: (_) => setState(() {
                        _status = entry.key;
                        _load();
                      }),
                      selectedColor: AppColors.primary,
                      labelStyle: TextStyle(
                        color: _status == entry.key ? Colors.white : null,
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
              child: FutureBuilder<List<Project>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(cardHeight: 132);
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
                      Icons.work_outline,
                      'No projects',
                      _search.isNotEmpty
                          ? 'Nothing matches your search.'
                          : 'Projects you can access will appear here.',
                      buttonLabel: canCreate ? 'Create Project' : null,
                      onButton: canCreate ? _create : null,
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) =>
                        _ProjectCard(project: filtered[i]),
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

class _ProjectCard extends StatelessWidget {
  final Project project;
  const _ProjectCard({required this.project});

  String get _dates {
    final start = project.startDate ?? '—';
    final end = project.endDate ?? '—';
    return '$start → $end';
  }

  String get _budget {
    final value = double.tryParse(project.budget);
    if (value == null) return project.budget;
    if (value >= 1000000) {
      return 'KES ${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) return 'KES ${(value / 1000).toStringAsFixed(0)}K';
    return 'KES ${value.toStringAsFixed(0)}';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ProjectDetailScreen(
              projectId: project.id,
              title: project.projectName,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      project.projectName,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  StatusBadge(project.status),
                ],
              ),
              if (project.description.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  project.description,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: AppColors.muted),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              ProjectProgressBar(project.timelineProgress, label: 'Timeline'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  InfoChip(Icons.calendar_today_outlined, _dates),
                  InfoChip(Icons.payments_outlined, _budget),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
