import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Rounded status pill, colored consistently across the whole app.
///
/// Maps every status the API can return (projects, reports, milestones,
/// beneficiaries) onto the design system's foreground-on-tint pairs:
/// green = healthy, amber = in progress, blue = completed, red = bad,
/// grey = dormant.
class StatusBadge extends StatelessWidget {
  final String status;

  /// Optional display override; defaults to a prettified [status].
  final String? label;

  /// Larger variant (11px, roomier padding) for primary list cards.
  final bool large;

  const StatusBadge(this.status, {super.key, this.label, this.large = false});

  static (Color, Color) colorsFor(String status) => switch (status) {
        'active' || 'approved' => (AppColors.success, AppColors.successTint),
        'planning' || 'submitted' => (AppColors.warning, AppColors.warningTint),
        'completed' => (AppColors.info, AppColors.infoTint),
        'cancelled' || 'overdue' || 'inactive' =>
          (AppColors.danger, AppColors.dangerTint),
        // on_hold, draft, pending, and anything unrecognised.
        _ => (AppColors.neutral, AppColors.neutralTint),
      };

  static String labelFor(String status) => switch (status) {
        'on_hold' => 'On Hold',
        '' => '—',
        _ => status[0].toUpperCase() + status.substring(1),
      };

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = colorsFor(status);
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
          : const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        (label ?? labelFor(status)).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: large ? 11 : 10,
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
            ),
      ),
    );
  }
}
