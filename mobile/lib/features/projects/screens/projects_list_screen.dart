import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/auth_provider.dart';
import '../models/project.dart';
import '../project_repository.dart';
import 'project_detail_screen.dart';

/// Official table-style project register: filter bar, green column header,
/// and alternating rows (eCitizen style).
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
    null: 'All statuses',
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
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('PROJECT REGISTER'),
            if (_count != null)
              Text(
                '$_count project${_count == 1 ? '' : 's'} on record',
                style: const TextStyle(
                    color: Colors.white70, fontSize: 10, letterSpacing: 0.2),
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
                      hintText: 'Search projects...',
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
                  tooltip: 'Filter by status',
                  onSelected: (v) => setState(() {
                    _status = v == '__all__' ? null : v;
                    _load();
                  }),
                  itemBuilder: (_) => [
                    for (final e in _statuses.entries)
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
                          _status == null
                              ? 'Filter'
                              : _statuses[_status]!,
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
                Expanded(
                    flex: 3,
                    child: Text('PROJECT NAME', style: _headerStyle)),
                Expanded(flex: 2, child: Text('STATUS', style: _headerStyle)),
                Expanded(
                    flex: 2,
                    child: Text('PROGRESS',
                        style: _headerStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () async => setState(_load),
              child: FutureBuilder<List<Project>>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const ShimmerList(cardHeight: 56);
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
                      Icons.folder_open_outlined,
                      'No projects',
                      _search.isNotEmpty
                          ? 'Nothing matches your search.'
                          : 'Projects you can access will appear here.',
                      buttonLabel: canCreate ? 'Create Project' : null,
                      onButton: canCreate ? _create : null,
                    );
                  }
                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 88),
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _ProjectTableRow(
                      project: filtered[i],
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

/// Alternating table row: linked name + description, status badge, progress.
class _ProjectTableRow extends StatelessWidget {
  final Project project;
  final bool even;
  const _ProjectTableRow({required this.project, required this.even});

  @override
  Widget build(BuildContext context) {
    final progress = project.timelineProgress.clamp(0.0, 1.0);
    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ProjectDetailScreen(
            projectId: project.id,
            title: project.projectName,
          ),
        ),
      ),
      child: Container(
        color: even ? Colors.white : AppColors.surfaceVariant,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    project.projectName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.info, // official link colour
                    ),
                  ),
                  if (project.description.isNotEmpty)
                    Text(
                      project.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textMuted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(project.status),
              ),
            ),
            Expanded(
              flex: 2,
              child: Column(
                children: [
                  Text(
                    '${(progress * 100).round()}%',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: AppColors.border,
                      color: AppColors.primary,
                      minHeight: 4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
