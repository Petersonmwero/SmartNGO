import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../shared/widgets/official_card.dart';
import '../models/impact_summary.dart';
import 'evm_cards.dart' show formatKes;

/// Donor-facing impact card: who the project reached and what that cost,
/// per approved field reports only.
///
/// Deliberately explicit about that scope — an empty card means "nothing
/// approved yet", not "no work done", and saying so avoids a manager reading
/// zeros as failure.
class ProjectImpactCard extends StatelessWidget {
  final ImpactSummary summary;

  const ProjectImpactCard({super.key, required this.summary});

  /// Whole shillings with thousands separators, e.g. 4542.86 -> "4,543".
  static String _withSeparators(double value) {
    final digits = value.round().toString();
    final buffer = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
      buffer.write(digits[i]);
    }
    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    return OfficialCard(
      title: 'Impact Reported',
      child: summary.isEmpty ? _empty(context) : _content(context),
    );
  }

  Widget _empty(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Text(
        'No approved field reports yet. Reach and spend figures appear here '
        'once a manager approves a report.',
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: AppColors.textMuted),
      ),
    );
  }

  Widget _content(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _Figure(
                value: '${summary.reached}',
                label: 'People reached',
              ),
            ),
            Container(width: 1, height: 42, color: AppColors.border),
            Expanded(
              child: _Figure(
                // Not formatKes: abbreviating 4,543 to "KES 5K" loses the
                // precision that makes a per-person cost meaningful.
                value: summary.costPerBeneficiary == null
                    ? '—'
                    : 'KES ${_withSeparators(summary.costPerBeneficiary!)}',
                label: 'Cost per person',
              ),
            ),
            Container(width: 1, height: 42, color: AppColors.border),
            Expanded(
              child: _Figure(
                value: '${summary.approvedReports}',
                label: 'Approved reports',
              ),
            ),
          ],
        ),
        if (summary.reached > 0) ...[
          const SizedBox(height: 14),
          _ReachBar(summary: summary),
        ],
        if (summary.byActivity.isNotEmpty) ...[
          const Divider(height: 24),
          for (final row in summary.byActivity)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(row.label,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textPrimary)),
                  ),
                  Text('${row.reached} reached',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 74,
                    child: Text(
                      formatKes(row.amountSpent),
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

class _Figure extends StatelessWidget {
  final String value;
  final String label;
  const _Figure({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primary)),
        const SizedBox(height: 2),
        Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
      ],
    );
  }
}

/// Gender split of the people reached, with the unrecorded remainder shown
/// rather than silently dropped.
class _ReachBar extends StatelessWidget {
  final ImpactSummary summary;
  const _ReachBar({required this.summary});

  @override
  Widget build(BuildContext context) {
    final segments = <(int, Color, String)>[
      (summary.female, AppColors.accent, 'female'),
      (summary.male, AppColors.primary, 'male'),
      (summary.unspecified, AppColors.border, 'unspecified'),
    ].where((s) => s.$1 > 0).toList();
    if (segments.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 8,
          child: Row(
            children: [
              for (final (count, color, _) in segments)
                Expanded(flex: count, child: ColoredBox(color: color)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 12,
          children: [
            for (final (count, color, label) in segments)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 8, height: 8, color: color),
                  const SizedBox(width: 4),
                  Text('$count $label',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.textSecondary)),
                ],
              ),
            if (summary.youth > 0)
              Text('incl. ${summary.youth} youth',
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      ],
    );
  }
}
