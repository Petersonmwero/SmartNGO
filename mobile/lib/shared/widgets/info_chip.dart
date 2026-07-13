import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Small grey metadata chip: icon + label (dates, counts, budgets on cards).
class InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const InfoChip(this.icon, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.neutralTint.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.muted),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontSize: 11,
                  color: AppColors.muted,
                ),
          ),
        ],
      ),
    );
  }
}
