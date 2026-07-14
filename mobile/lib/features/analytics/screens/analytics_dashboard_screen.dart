import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_text_styles.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/shimmer_card.dart';
import '../../beneficiaries/beneficiary_repository.dart';
import '../analytics_repository.dart';

/// Analytics dashboard with charts for projects, reports, and beneficiaries.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AnalyticsRepository>().dashboard();
    _loadDemographics();
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
      appBar: AppBar(title: const Text('Analytics')),
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
                  const Icon(Icons.bar_chart, size: 52, color: AppColors.muted),
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
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // KPI summary rows (2×2)
          Row(
            children: [
              _KpiTile('Total Projects', '${stats.projects.total}',
                  Icons.work_outline, AppColors.primary),
              const SizedBox(width: 12),
              _KpiTile(
                  'Active Projects',
                  '${stats.projects.byStatus['active'] ?? 0}',
                  Icons.play_circle_outline,
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _KpiTile('Beneficiaries', '${stats.beneficiaries}',
                  Icons.people_outline, AppColors.secondary),
              const SizedBox(width: 12),
              _KpiTile('Total Reports', '$totalReports',
                  Icons.description_outlined, AppColors.accent),
            ],
          ),
          const SizedBox(height: 24),

          // Projects by status — pie chart
          _SectionHeader('Projects by Status'),
          const SizedBox(height: 12),
          _ProjectsPieChart(byStatus: stats.projects.byStatus),
          const SizedBox(height: 24),

          // Reports — bar chart
          _SectionHeader('Reports Overview'),
          const SizedBox(height: 12),
          _ReportsBarChart(reports: stats.reports),
          const SizedBox(height: 24),

          // Beneficiary demographics — pie chart
          _SectionHeader('Beneficiary Demographics'),
          const SizedBox(height: 12),
          _DemographicsPieChart(female: femaleCount, male: maleCount),
        ],
      ),
    );
  }
}

/// Male/female beneficiary split with percentage labels.
class _DemographicsPieChart extends StatelessWidget {
  final int? female;
  final int? male;
  const _DemographicsPieChart({required this.female, required this.male});

  @override
  Widget build(BuildContext context) {
    final f = female ?? 0;
    final m = male ?? 0;
    final total = f + m;
    if (total == 0) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No beneficiary data yet.')),
        ),
      );
    }

    String pct(int v) => '${(v * 100 / total).round()}%';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 180,
              child: PieChart(
                PieChartData(
                  // Amber = female, green = male — same coding as the
                  // beneficiary list avatars.
                  sections: [
                    if (f > 0)
                      PieChartSectionData(
                        value: f.toDouble(),
                        color: AppColors.accent,
                        radius: 56,
                        title: pct(f),
                        titleStyle: const TextStyle(
                            color: AppColors.charcoal,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    if (m > 0)
                      PieChartSectionData(
                        value: m.toDouble(),
                        color: AppColors.primaryMid,
                        radius: 56,
                        title: pct(m),
                        titleStyle: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                  ],
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              children: [
                _legendDot(context, AppColors.accent, 'Female ($f)'),
                _legendDot(context, AppColors.primaryMid, 'Male ($m)'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    return Text(title, style: Theme.of(context).textTheme.titleMedium);
  }
}

class _KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _KpiTile(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 10),
              Text(value, style: AppTextStyles.kpiNumber),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
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
      if (count == 0) { idx++; return; }
      final isTouched = idx == _touched;
      sections.add(PieChartSectionData(
        value: count.toDouble(),
        color: _colors[key] ?? Colors.grey,
        radius: isTouched ? 72 : 60,
        title: '$count',
        titleStyle: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ));
      idx++;
    });

    if (sections.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(child: Text('No projects yet.')),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: sections,
                  pieTouchData: PieTouchData(
                    touchCallback: (event, response) {
                      setState(() {
                        _touched = response?.touchedSection?.touchedSectionIndex ?? -1;
                      });
                    },
                  ),
                  sectionsSpace: 2,
                  centerSpaceRadius: 48,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: _labels.entries.map((e) {
                final count = widget.byStatus[e.key] ?? 0;
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                          color: _colors[e.key], shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text('${e.value} ($count)',
                        style: Theme.of(context).textTheme.labelSmall),
                  ],
                );
              }).toList(),
            ),
          ],
        ),
      ),
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
        BarChartRodData(toY: reports.draft.toDouble(), color: AppColors.muted, width: 28, borderRadius: BorderRadius.circular(4)),
      ]),
      BarChartGroupData(x: 1, barRods: [
        BarChartRodData(toY: reports.submitted.toDouble(), color: AppColors.accent, width: 28, borderRadius: BorderRadius.circular(4)),
      ]),
      BarChartGroupData(x: 2, barRods: [
        BarChartRodData(toY: reports.approved.toDouble(), color: AppColors.statusActive, width: 28, borderRadius: BorderRadius.circular(4)),
      ]),
    ];

    final maxY = [reports.draft, reports.submitted, reports.approved]
        .fold<double>(0, (m, v) => m < v ? v.toDouble() : m);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 20, 20, 12),
        child: SizedBox(
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
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
            ),
          ),
        ),
      ),
    );
  }
}
