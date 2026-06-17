import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/auth_provider.dart';
import '../../reports/screens/submit_report_screen.dart';
import '../models/assignment.dart';
import '../models/indicator.dart';
import '../models/milestone.dart';
import '../models/project.dart';
import '../project_repository.dart';

class ProjectDetailScreen extends StatefulWidget {
  final int projectId;
  final String title;

  const ProjectDetailScreen({
    super.key,
    required this.projectId,
    required this.title,
  });

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  late final ProjectRepository _repo;
  late Future<Project> _project;
  late Future<List<Milestone>> _milestones;
  late Future<List<ProjectAssignment>> _team;
  late Future<List<Indicator>> _indicators;

  @override
  void initState() {
    super.initState();
    _repo = context.read<ProjectRepository>();
    _project = _repo.get(widget.projectId);
    _milestones = _repo.milestones(widget.projectId);
    _team = _repo.assignments(widget.projectId);
    _indicators = _repo.indicators(widget.projectId);
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthProvider>().user?.role;
    final canReport = role == 'officer' || role == 'manager' || role == 'admin';

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.title),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Overview'),
              Tab(text: 'Milestones'),
              Tab(text: 'Team'),
              Tab(text: 'KPIs'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(future: _project),
            _MilestonesTab(future: _milestones),
            _TeamTab(future: _team),
            _KpisTab(future: _indicators),
          ],
        ),
        floatingActionButton: canReport
            ? FloatingActionButton.extended(
                icon: const Icon(Icons.add),
                label: const Text('Report'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SubmitReportScreen(
                      projectId: widget.projectId,
                      projectName: widget.title,
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}

/// Generic async tab body.
class _AsyncTab<T> extends StatelessWidget {
  final Future<T> future;
  final Widget Function(T data) builder;
  const _AsyncTab({required this.future, required this.builder});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        return builder(snapshot.data as T);
      },
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Future<Project> future;
  const _OverviewTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<Project>(
      future: future,
      builder: (p) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(p.projectName,
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          Chip(label: Text(p.statusLabel)),
          const SizedBox(height: 16),
          if (p.description.isNotEmpty) ...[
            Text(p.description),
            const SizedBox(height: 16),
          ],
          _row('Budget', p.budget),
          _row('Start', p.startDate ?? '—'),
          _row('End', p.endDate ?? '—'),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            SizedBox(width: 90, child: Text(label)),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _MilestonesTab extends StatelessWidget {
  final Future<List<Milestone>> future;
  const _MilestonesTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<Milestone>>(
      future: future,
      builder: (items) => items.isEmpty
          ? const Center(child: Text('No milestones.'))
          : ListView(
              children: [
                for (final m in items)
                  ListTile(
                    leading: Icon(
                      m.status == 'completed'
                          ? Icons.check_circle
                          : m.status == 'overdue'
                              ? Icons.warning
                              : Icons.radio_button_unchecked,
                    ),
                    title: Text(m.title),
                    subtitle: Text('Due: ${m.dueDate ?? '—'}'),
                    trailing: Text(m.status),
                  ),
              ],
            ),
    );
  }
}

class _TeamTab extends StatelessWidget {
  final Future<List<ProjectAssignment>> future;
  const _TeamTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<ProjectAssignment>>(
      future: future,
      builder: (items) => items.isEmpty
          ? const Center(child: Text('No team members assigned.'))
          : ListView(
              children: [
                for (final a in items)
                  ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(a.userName),
                    trailing: Text(a.role),
                  ),
              ],
            ),
    );
  }
}

class _KpisTab extends StatelessWidget {
  final Future<List<Indicator>> future;
  const _KpisTab({required this.future});

  @override
  Widget build(BuildContext context) {
    return _AsyncTab<List<Indicator>>(
      future: future,
      builder: (items) => items.isEmpty
          ? const Center(child: Text('No indicators.'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final ind in items)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(ind.indicatorName,
                              style: Theme.of(context).textTheme.titleMedium),
                          const SizedBox(height: 8),
                          LinearProgressIndicator(value: ind.fraction),
                          const SizedBox(height: 8),
                          Text(
                              '${ind.currentValue} / ${ind.targetValue} ${ind.unit}'
                              '  (${ind.progressPercent?.toStringAsFixed(1) ?? '—'}%)'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
