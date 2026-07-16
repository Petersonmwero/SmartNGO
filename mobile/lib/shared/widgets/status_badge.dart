import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Official eCitizen-style status badge: uppercase label, 1px status-colour
/// border on a pale status surface, squared 2px corners.
///
/// Maps every status the API can return (projects, reports, milestones,
/// beneficiaries) onto the official government status palette.
class StatusBadge extends StatelessWidget {
  final String status;

  /// Optional display override; defaults to a prettified [status].
  final String? label;

  /// Larger variant (11px, roomier padding) for primary list cards.
  final bool large;

  const StatusBadge(this.status, {super.key, this.label, this.large = false});

  /// Vivid accent for the left bar on project cards.
  static Color accentFor(String status) => switch (status) {
        'active' => AppColors.primary,
        'planning' => AppColors.accent,
        'on_hold' => AppColors.error,
        'completed' => AppColors.info,
        // cancelled and anything unrecognised.
        _ => AppColors.textMuted,
      };

  static (Color, Color) colorsFor(String status) => switch (status) {
        'active' || 'approved' => (AppColors.success, AppColors.successTint),
        'planning' || 'submitted' => (AppColors.warning, AppColors.warningTint),
        'completed' => (AppColors.info, AppColors.infoTint),
        'on_hold' || 'cancelled' || 'overdue' || 'inactive' =>
          (AppColors.danger, AppColors.dangerTint),
        // draft, pending, and anything unrecognised.
        _ => (AppColors.neutral, Color(0xFFF5F5F5)),
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
          ? const EdgeInsets.symmetric(horizontal: 10, vertical: 4)
          : const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        border: Border.all(color: fg),
        borderRadius: BorderRadius.circular(2),
      ),
      child: Text(
        (label ?? labelFor(status)).toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: large ? 11 : 10,
              color: fg,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
      ),
    );
  }
}
