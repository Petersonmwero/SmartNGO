import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/api_exception.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/official_card.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../auth/auth_provider.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../../ngos/ngo_repository.dart';
import '../analytics_repository.dart';

/// Official analytics dashboard: green summary statistics bar plus bordered
/// OfficialCard chart sections (eCitizen style).
class AnalyticsDashboardScreen extends StatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  State<AnalyticsDashboardScreen> createState() =>
      _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends State<AnalyticsDashboardScreen> {
  late Future<DashboardStats> _future;
  int? _femaleCount;
  int? _maleCount;
  String? _ngoName;

  @override
  void initState() {
    super.initState();
    _load();
    WidgetsBinding.instance.addPostFrameCallback((_) => _resolveNgoName());
  }

  void _load() {
    _future = context.read<AnalyticsRepository>().dashboard();
    _loadDemographics();
  }

  /// Best-effort: resolve the NGO's display name for the header subtitle
  /// (the authenticated payload only carries the NGO id).
  Future<void> _resolveNgoName() async {
    final ngoId = context.read<AuthProvider>().user?.ngoId;
    if (ngoId == null) return;
    try {
      final ngos = await context.read<NgoRepository>().listPublic();
      final match = ngos.where((n) => n.id == ngoId);
      if (mounted && match.isNotEmpty) {
        setState(() => _ngoName = match.first.name);
      }
    } on ApiException {
      // Subtitle falls back to the system name alone.
    }
  }

  Future<void> _loadDemographics() async {
    try {
      final repo = context.read<BeneficiaryRepository>();
      final female = await repo.count(gender: 'female');
      final male = await repo.count(gender: 'male');
      if (!mounted) return;
      setState(() {
        _femaleCount = female;
        _maleCount = male;
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ANALYTICS DASHBOARD'),
            Text(
              _ngoName == null
                  ? 'Smart NGO M&E System'
                  : 'Smart NGO M&E — $_ngoName',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  color: Colors.white70, fontSize: 10, letterSpacing: 0.2),
            ),
          ],
        ),
      ),
      body: FutureBuilder<DashboardStats>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ShimmerList(cardHeight: 120);
          }
          if (snap.hasError) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bar_chart,
                      size: 52, color: AppColors.textMuted),
                  const SizedBox(height: 12),
                  const Text('Failed to load analytics.'),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => setState(_load),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          return _Dashboard(
            stats: snap.data!,
            femaleCount: _femaleCount,
            maleCount: _maleCount,
            onRefresh: () async => setState(_load),
          );
        },
      ),
    );
  }
}

class _Dashboard extends StatelessWidget {
  final DashboardStats stats;
  final int? femaleCount;
  final int? maleCount;
  final Future<void> Function() onRefresh;

  const _Dashboard({
    required this.stats,
    required this.femaleCount,
    required this.maleCount,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final totalReports =
        stats.reports.draft + stats.reports.submitted + stats.reports.approved;
    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Green summary statistics bar.
          Container(
            color: AppColors.primary,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                _MiniStat('${stats.projects.total}', 'Projects'),
                _vSep(),
                _MiniStat('${stats.beneficiaries}', 'Beneficiaries'),
                _vSep(),
                _MiniStat('$totalReports', 'Reports'),
                _vSep(),
                _MiniStat('${stats.reports.approved}', 'Approved'),
              ],
            ),
          ),
          const SizedBox(height: 6),
          OfficialCard(
            title: 'Projects by Status',
            child: _ProjectsPieChart(byStatus: stats.projects.byStatus),
          ),
          OfficialCard(
            title: 'Reports Overview',
            child: _ReportsBarChart(reports: stats.reports),
          ),
          OfficialCard(
            title: 'Beneficiary Demographics',
            child:
                _DemographicsSection(female: femaleCount, male: maleCount),
          ),
        ],
      ),
    );
  }

  Widget _vSep() =>
      Container(width: 1, height: 32, color: Colors.white24);
}

class _MiniStat extends StatelessWidget {
  final String value;
  final String label;
  const _MiniStat(this.value, this.label);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  color: AppColors.accentLight,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(color: Colors.white70, fontSize: 10)),
        ],
      ),
    );
  }
}

/// Beneficiary gender split: donut chart plus an official table row.
class _DemographicsSection extends StatelessWidget {
  final int? female;
  final int? male;
  const _DemographicsSection({required this.female, required this.male});

  @override
  Widget build(BuildContext context) {
    final f = female ?? 0;
    final m = male ?? 0;
    final total = f + m;
    if (total == 0) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No beneficiary data yet.')),
      );
    }

    String pct(int v) => '${(v * 100 / total).round()}%';

    return Column(
      children: [
        SizedBox(
          height: 170,
          child: PieChart(
            PieChartData(
              sections: [
                if (f > 0)
                  PieChartSectionData(
                    value: f.toDouble(),
                    color: AppColors.accent,
                    radius: 52,
                    title: pct(f),
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                if (m > 0)
                  PieChartSectionData(
                    value: m.toDouble(),
                    color: AppColors.primary,
                    radius: 52,
                    title: pct(m),
                    titleStyle: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
              ],
              sectionsSpace: 2,
              centerSpaceRadius: 38,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // Official table summary.
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Row(
            children: [
              _demoCell(context, AppColors.accent, 'Female', '$f (${pct(f)})'),
              Container(width: 1, height: 36, color: AppColors.border),
              _demoCell(context, AppColors.primary, 'Male', '$m (${pct(m)})'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _demoCell(
      BuildContext context, Color color, String label, String value) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: 6),
            Text('$label: ',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}

/// Pie chart showing project distribution by status.
class _ProjectsPieChart extends StatefulWidget {
  final Map<String, int> byStatus;
  const _ProjectsPieChart({required this.byStatus});

  @override
  State<_ProjectsPieChart> createState() => _ProjectsPieChartState();
}

class _ProjectsPieChartState extends State<_ProjectsPieChart> {
  int _touched = -1;

  static const _colors = {
    'active': AppColors.statusActive,
    'planning': AppColors.statusPlanning,
    'on_hold': AppColors.statusOnHold,
    'completed': AppColors.statusCompleted,
    'cancelled': AppColors.statusCancelled,
  };

  static const _labels = {
    'active': 'Active',
    'planning': 'Planning',
    'on_hold': 'On Hold',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final sections = <PieChartSectionData>[];
    int idx = 0;
    widget.byStatus.forEach((key, count) {
      if (count == 0) {
        idx++;
        return;
      }
      final isTouched = idx == _touched;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: _colors[key] ?? Colors.grey,
        radius: isTouched ? 66 : 56,
        title: '$count',
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ));
      idx++;
    });

    if (sections.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: Text('No projects yet.')),
      );
    }

    return Column(
      children: [
        SizedBox(
          height: 190,
          child: PieChart(
            PieChartData(
              sections: sections,
              pieTouchData: PieTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touched =
                        response?.touchedSection?.touchedSectionIndex ?? -1;
                  });
                },
              ),
              sectionsSpace: 2,
              centerSpaceRadius: 44,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 6,
          children: _labels.entries.map((e) {
            final count = widget.byStatus[e.key] ?? 0;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 10, height: 10, color: _colors[e.key]),
                const SizedBox(width: 4),
                Text('${e.value} ($count)',
                    style: Theme.of(context).textTheme.labelSmall),
              ],
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Bar chart showing reports by status.
class _ReportsBarChart extends StatelessWidget {
  final ReportStats reports;
  const _ReportsBarChart({required this.reports});

  @override
  Widget build(BuildContext context) {
    final groups = [
      BarChartGroupData(x: 0, barRods: [
        BarChartRodData(
            toY: reports.draft.toDouble(),
            color: AppColors.neutral,
            width: 28,
            borderRadius: BorderRadius.circular(2)),
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(
            toY: reports.submitted.toDouble(),
            color: AppColors.warning,
            width: 28,
            borderRadius: BorderRadius.circular(2)),
      ]),
      BarChartGroupData(x: 2, barRods: [
        BarChartRodData(
            toY: reports.approved.toDouble(),
            color: AppColors.primary,
            width: 28,
            borderRadius: BorderRadius.circular(2)),
      ]),
    ];

    final maxY = [reports.draft, reports.submitted, reports.approved]
        .fold<double>(0, (m, v) => m < v ? v.toDouble() : m);

    return SizedBox(
      height: 180,
      child: BarChart(
        BarChartData(
          barGroups: groups,
          maxY: maxY + 2,
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (v, _) => Text(
                  v.toInt().toString(),
                  style: Theme.of(context).textTheme.labelSmall,
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (v, _) {
                  const labels = ['Draft', 'Submitted', 'Approved'];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      labels[v.toInt()],
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                },
              ),
            ),
            rightTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles:
                const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          gridData: const FlGridData(show: true, drawVerticalLine: false),
        ),
      ),
    );
  }
}
