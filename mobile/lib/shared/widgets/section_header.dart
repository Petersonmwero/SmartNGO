import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Section title row with an optional trailing action ("See all →").
class SectionHeader extends StatelessWidget {
  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? color;

  const SectionHeader(
    this.title, {
    super.key,
    this.actionLabel,
    this.onAction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: color ?? AppColors.charcoal,
                ),
          ),
          if (actionLabel != null)
            GestureDetector(
              onTap: onAction,
              child: Text(
                '$actionLabel →',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}
