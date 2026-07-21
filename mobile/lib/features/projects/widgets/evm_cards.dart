import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/official_card.dart';
import '../models/milestone.dart';
import '../models/project.dart';

/// Short "KES 1.7M / 400K" money format shared by the EVM cards.
String formatKes(double value) {
  if (value >= 1000000) return 'KES ${(value / 1000000).toStringAsFixed(2)}M';
  if (value >= 1000) return 'KES ${(value / 1000).toStringAsFixed(0)}K';
  return 'KES ${value.toStringAsFixed(0)}';
}

// ── LIST PROGRESS TRACK ────────────────────────────────────────────────────

/// Compact EVM track for list rows: composite fill, the physical (earned
/// value) segment drawn over it, and a tick at planned value.
///
/// The tick is only meaningful against the *physical* segment — SPI is
/// EV/PV — which is why physical is drawn as its own darker band rather than
/// letting the composite fill stand in for delivery. Physical past the tick
/// means ahead of the plan.
class EvmProgressTrack extends StatelessWidget {
  final Project project;

  /// Track thickness; the tick overhangs it by [_tickOverhang] either side.
  final double height;

  static const double _tickOverhang = 3;
  static const double _tickWidth = 2;

  /// Identifies the planned-value tick, which is absent when PV is 0.
  static const Key tickKey = Key('evm-planned-tick');

  /// Identifies the earned-value (physical) band.
  static const Key physicalBandKey = Key('evm-physical-band');

  const EvmProgressTrack({super.key, required this.project, this.height = 6});

  static double _fraction(double percent) => (percent / 100).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final composite = project.compositeFraction;
    final physical = _fraction(project.physicalProgress);
    final planned = _fraction(project.plannedValueProgress);
    return Tooltip(
      message: 'Delivered ${project.physicalProgress.toStringAsFixed(1)}% · '
          'planned ${project.plannedValueProgress.toStringAsFixed(1)}% · '
          'overall ${project.progressPercentage.round()}%',
      child: SizedBox(
        height: height + _tickOverhang * 2,
        child: Stack(
          alignment: Alignment.center,
          // FractionallySizedBox + Align keep this free of LayoutBuilder,
          // which cannot compute intrinsics and breaks inside IntrinsicHeight.
          children: [
            Container(height: height, color: AppColors.border),
            _Band(widthFactor: composite, height: height, color: _compositeColor),
            _Band(
              key: physicalBandKey,
              widthFactor: physical,
              height: height,
              color: AppColors.primary,
            ),
            if (planned > 0)
              Align(
                key: tickKey,
                // -1 pins the tick's left edge to the track's left edge and
                // +1 its right edge to the right, so it never spills out.
                alignment: Alignment(planned * 2 - 1, 0),
                child: Container(
                  width: _tickWidth,
                  height: height + _tickOverhang * 2,
                  color: AppColors.textPrimary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// Composite sits behind the earned-value band, so it is tinted to stay
  /// visually subordinate to it.
  static const Color _compositeColor = Color(0x66006633);
}

class _Band extends StatelessWidget {
  final double widthFactor;
  final double height;
  final Color color;

  const _Band({
    super.key,
    required this.widthFactor,
    required this.height,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Align(
        // The Align is load-bearing: a bare FractionallySizedBox is sized to
        // its factor and then positioned by the Stack's own alignment, which
        // centres the band instead of anchoring it to the left of the track.
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: widthFactor,
          child: Container(height: height, color: color),
        ),
      );
}

/// One-line key for [EvmProgressTrack], shown once under a list's column
/// header rather than repeated on every row.
class EvmTrackLegend extends StatelessWidget {
  const EvmTrackLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      // Explicit width: in a centred Column (the dashboard card) the strip
      // would otherwise shrink-wrap its keys and float mid-card.
      width: double.infinity,
      color: AppColors.surfaceVariant,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 2,
        children: const [
          _LegendKey(color: AppColors.primary, label: 'Delivered'),
          _LegendKey(color: EvmProgressTrack._compositeColor, label: 'Overall'),
          _LegendKey(
              color: AppColors.textPrimary, label: 'Planned', isTick: true),
        ],
      ),
    );
  }
}

class _LegendKey extends StatelessWidget {
  final Color color;
  final String label;
  final bool isTick;

  const _LegendKey({
    required this.color,
    required this.label,
    this.isTick = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isTick ? 2 : 12,
          height: isTick ? 10 : 6,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(fontSize: 9, color: AppColors.textMuted)),
      ],
    );
  }
}

// ── PROJECT PROGRESS ───────────────────────────────────────────────────────

/// Official card showing the weighted composite progress: a circular
/// composite indicator plus the three EVM dimensions (financial 30%,
/// physical 50%, time 20%), each with its own bar and explanation line.
class ProjectProgressCard extends StatelessWidget {
  final Project project;

  /// Milestones, when already loaded, feed the "3 of 12 milestone weights"
  /// explanation; a percentage-only line is shown until they arrive.
  final List<Milestone>? milestones;

  const ProjectProgressCard({super.key, required this.project, this.milestones});

  String get _physicalDetail {
    final items = milestones;
    if (items == null || items.isEmpty) {
      return '${project.physicalProgress.round()}% of milestone weight delivered';
    }
    final total = items.fold<int>(0, (sum, m) => sum + m.weight);
    final done = items
        .where((m) => m.status == 'completed')
        .fold<int>(0, (sum, m) => sum + m.weight);
    return '$done of $total milestone weights delivered';
  }

  String get _timeDetail {
    final total = project.totalDays;
    final elapsed = project.elapsedDays;
    if (total == null || elapsed == null) return 'No timeline set';
    return '$elapsed of $total project days elapsed';
  }

  @override
  Widget build(BuildContext context) {
    final budget = double.tryParse(project.budget) ?? 0;
    return OfficialCard(
      title: 'Project Progress',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'OVERALL COMPLETION',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: AppColors.textMuted),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Weighted composite: financial 30% + physical 50% '
                      '+ time 20%',
                      style:
                          TextStyle(fontSize: 10, color: AppColors.textMuted),
                    ),
                  ],
                ),
              ),
              _CompositeRing(percentage: project.progressPercentage),
            ],
          ),
          const Divider(height: 24),
          _DimensionRow(
            label: 'Financial Progress',
            percentage: project.financialProgress,
            color: AppColors.primary,
            detail:
                '${formatKes(project.totalSpent)} of ${formatKes(budget)} spent',
          ),
          const SizedBox(height: 14),
          _DimensionRow(
            label: 'Physical Progress',
            percentage: project.physicalProgress,
            color: AppColors.info,
            detail: _physicalDetail,
          ),
          const SizedBox(height: 14),
          _DimensionRow(
            label: 'Time Progress',
            percentage: project.timeProgress,
            color: AppColors.accent,
            detail: _timeDetail,
          ),
        ],
      ),
    );
  }
}

/// 64px circular composite-progress indicator with the percentage centred.
class _CompositeRing extends StatelessWidget {
  final double percentage;
  const _CompositeRing({required this.percentage});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 64,
      height: 64,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CircularProgressIndicator(
            value: (percentage / 100).clamp(0.0, 1.0),
            strokeWidth: 6,
            backgroundColor: AppColors.border,
            color: AppColors.primary,
          ),
          Center(
            child: Text(
              '${percentage.round()}%',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final String label;
  final double percentage;
  final Color color;
  final String detail;

  const _DimensionRow({
    required this.label,
    required this.percentage,
    required this.color,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(
              '${percentage.round()}%',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ],
        ),
        const SizedBox(height: 4),
        LinearProgressIndicator(
          value: (percentage / 100).clamp(0.0, 1.0),
          backgroundColor: AppColors.border,
          color: color,
          minHeight: 6,
        ),
        const SizedBox(height: 3),
        Text(detail,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

// ── PROJECT HEALTH ─────────────────────────────────────────────────────────

/// Official card with the health badge and CPI/SPI performance indices,
/// each with a plain-language interpretation line.
class ProjectHealthCard extends StatelessWidget {
  final Project project;
  const ProjectHealthCard({super.key, required this.project});

  (String, Color) get _cpiReading {
    final cpi = project.costPerformanceIndex;
    if (cpi == null) return ('No spending recorded yet', AppColors.textMuted);
    if (cpi >= 1.0) return ('Delivering more value than spent ✓', AppColors.success);
    if (cpi >= 0.8) return ('Slightly over budget', AppColors.warning);
    return ('Spending faster than delivering ⚠', AppColors.danger);
  }

  (String, Color) get _spiReading {
    final spi = project.schedulePerformanceIndex;
    // SPI is earned value over planned value, so the reading compares
    // delivery against the work the plan scheduled — not calendar elapsed.
    if (spi == null) return ('No work scheduled yet', AppColors.textMuted);
    if (spi >= 1.0) return ('Ahead of planned work ✓', AppColors.success);
    if (spi >= 0.8) return ('Slightly behind planned work', AppColors.warning);
    return ('Behind planned work ⚠', AppColors.danger);
  }

  @override
  Widget build(BuildContext context) {
    final (cpiText, cpiColor) = _cpiReading;
    final (spiText, spiColor) = _spiReading;
    return OfficialCard(
      title: 'Project Health',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'OVERALL RATING',
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: AppColors.textMuted),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: project.healthColor.withValues(alpha: 0.1),
                  border: Border.all(color: project.healthColor),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Text(
                  project.healthLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                    color: project.healthColor,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _IndexRow(
            label: 'Cost Performance (CPI)',
            value: project.costPerformanceIndex,
            reading: cpiText,
            readingColor: cpiColor,
          ),
          const SizedBox(height: 12),
          _IndexRow(
            label: 'Schedule Performance (SPI)',
            value: project.schedulePerformanceIndex,
            reading: spiText,
            readingColor: spiColor,
            // Spells out the ratio behind the SPI figure, so the reading is
            // traceable to the phase baseline rather than to the calendar.
            // One decimal, matching the server: rounding both sides to whole
            // percents can print "20% vs 20%" next to an SPI of 1.02.
            footnote:
                'Earned ${project.physicalProgress.toStringAsFixed(1)}% of '
                'budgeted work vs '
                '${project.plannedValueProgress.toStringAsFixed(1)}% planned',
          ),
        ],
      ),
    );
  }
}

class _IndexRow extends StatelessWidget {
  final String label;
  final double? value;
  final String reading;
  final Color readingColor;

  /// Optional muted line under the reading, used to show the ratio the
  /// index was derived from.
  final String? footnote;

  const _IndexRow({
    required this.label,
    required this.value,
    required this.reading,
    required this.readingColor,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
            ),
            Text(
              value == null ? '—' : value!.toStringAsFixed(2),
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(reading, style: TextStyle(fontSize: 11, color: readingColor)),
        if (footnote != null) ...[
          const SizedBox(height: 2),
          Text(
            footnote!,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// ── PHASE BUDGET BREAKDOWN ─────────────────────────────────────────────────

/// Official green-headed table of phase allocations vs spend with a bold
/// total row, matching the eCitizen table style.
class PhaseBudgetTable extends StatelessWidget {
  final Project project;
  final bool canManage;
  final VoidCallback? onManage;

  const PhaseBudgetTable({
    super.key,
    required this.project,
    this.canManage = false,
    this.onManage,
  });

  static const _headerStyle = TextStyle(
      color: Colors.white,
      fontSize: 10,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.6);
  static const _cellStyle =
      TextStyle(fontSize: 11, color: AppColors.textPrimary);
  static const _boldCell = TextStyle(
      fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textPrimary);

  (IconData, Color) _statusIcon(String status) => switch (status) {
        'completed' => (Icons.check_circle, AppColors.success),
        'in_progress' => (Icons.autorenew, AppColors.info),
        _ => (Icons.hourglass_empty, AppColors.textMuted),
      };

  @override
  Widget build(BuildContext context) {
    final phases = project.phases;
    final budget = double.tryParse(project.budget) ?? 0;
    final totalAlloc =
        phases.fold<double>(0, (sum, p) => sum + p.allocatedBudget);
    final totalUtil = budget > 0
        ? (project.totalSpent / budget * 100).clamp(0, 100).round()
        : 0;

    return OfficialCard(
      title: 'Phase Budget Breakdown',
      contentPadding: EdgeInsets.zero,
      actionLabel: canManage ? 'Manage Phases' : null,
      onAction: canManage ? onManage : null,
      child: phases.isEmpty
          ? Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                canManage
                    ? 'No phases defined yet — use Manage Phases to plan '
                        'the budget breakdown.'
                    : 'No phases defined yet.',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textMuted),
              ),
            )
          : Column(
              children: [
                Container(
                  color: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 7),
                  child: const Row(
                    children: [
                      Expanded(
                          flex: 4,
                          child: Text('PHASE', style: _headerStyle)),
                      Expanded(
                          flex: 2,
                          child: Text('ALLOC',
                              style: _headerStyle,
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('SPENT',
                              style: _headerStyle,
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('UTIL',
                              style: _headerStyle,
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
                for (final (i, phase) in phases.indexed)
                  Container(
                    color: i.isEven ? Colors.white : AppColors.surfaceVariant,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 4,
                          child: Text(phase.phaseName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: _cellStyle),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_short(phase.allocatedBudget),
                              style: _cellStyle,
                              textAlign: TextAlign.right),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(_short(phase.spentBudget),
                              style: _cellStyle,
                              textAlign: TextAlign.right),
                        ),
                        Expanded(
                          flex: 2,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(
                                  '${phase.utilizationPercentage.round()}%',
                                  style: _cellStyle),
                              const SizedBox(width: 3),
                              Icon(_statusIcon(phase.status).$1,
                                  size: 12,
                                  color: _statusIcon(phase.status).$2),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 9),
                  decoration: const BoxDecoration(
                    border: Border(
                        top: BorderSide(
                            color: AppColors.borderStrong, width: 1.5)),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                          flex: 4, child: Text('TOTAL', style: _boldCell)),
                      Expanded(
                          flex: 2,
                          child: Text(_short(totalAlloc),
                              style: _boldCell,
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text(_short(project.totalSpent),
                              style: _boldCell,
                              textAlign: TextAlign.right)),
                      Expanded(
                          flex: 2,
                          child: Text('$totalUtil%',
                              style: _boldCell,
                              textAlign: TextAlign.right)),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  /// Compact money for table cells: 1.2M / 928K / 500.
  static String _short(double value) {
    if (value >= 1000000) {
      final m = value / 1000000;
      return m == m.roundToDouble()
          ? '${m.round()}M'
          : '${m.toStringAsFixed(2)}M';
    }
    if (value >= 1000) return '${(value / 1000).round()}K';
    return value.toStringAsFixed(0);
  }
}

/// Small green/amber/red dot signalling health next to status badges.
class HealthDot extends StatelessWidget {
  final Project project;
  final double size;
  const HealthDot({super.key, required this.project, this.size = 8});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Health: ${project.healthLabel}',
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: project.healthColor,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
