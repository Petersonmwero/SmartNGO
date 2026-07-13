import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// Dashboard KPI tile: icon in a green circle, a big Space Grotesk number
/// (amber by default), and a small grey label.
class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  /// Circle/icon color; defaults to the primary green.
  final Color? color;

  /// Number color; defaults to the amber accent.
  final Color? valueColor;
  final VoidCallback? onTap;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.color,
    this.valueColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconColor = color ?? AppColors.primary;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 12),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: valueColor ?? AppColors.accent,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: AppColors.muted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
