import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Animated progress bar with a label row ("Progress ... 72%") above a
/// green→sage gradient fill on a grey rounded track.
class ProjectProgressBar extends StatelessWidget {
  /// Progress in the range 0.0–1.0 (values outside are clamped).
  final double progress;
  final String? label;

  /// Track/fill thickness; dashboards use a slimmer 4px variant.
  final double height;

  const ProjectProgressBar(this.progress,
      {super.key, this.label, this.height = 6});

  @override
  Widget build(BuildContext context) {
    final clamped = progress.clamp(0.0, 1.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label ?? 'Progress',
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: AppColors.muted),
            ),
            Text(
              '${(clamped * 100).round()}%',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFFD1D5DB),
            borderRadius: BorderRadius.circular(999),
          ),
          alignment: Alignment.centerLeft,
          // Fraction-based fill (not LayoutBuilder) so the bar also works
          // inside IntrinsicHeight parents like accent-bar cards.
          child: AnimatedFractionallySizedBox(
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutCubic,
            alignment: Alignment.centerLeft,
            widthFactor: clamped,
            heightFactor: 1,
            child: Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
