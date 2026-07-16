import 'package:flutter/material.dart';

import '../../core/theme.dart';

/// eCitizen-style section card: bordered white container with a grey header
/// strip carrying a 4px green left rule and an uppercase green title, plus
/// an optional trailing action ("VIEW ALL →").
class OfficialCard extends StatelessWidget {
  final String title;
  final Widget child;
  final String? actionLabel;
  final VoidCallback? onAction;

  /// Overrides the header rule colour (e.g. red for danger sections).
  final Color? ruleColor;

  /// Content padding; pass EdgeInsets.zero for edge-to-edge tables.
  final EdgeInsetsGeometry contentPadding;

  const OfficialCard({
    super.key,
    required this.title,
    required this.child,
    this.actionLabel,
    this.onAction,
    this.ruleColor,
    this.contentPadding = const EdgeInsets.all(14),
  });

  @override
  Widget build(BuildContext context) {
    final rule = ruleColor ?? AppColors.primary;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              border: Border(
                bottom: const BorderSide(color: AppColors.border),
                left: BorderSide(color: rule, width: 4),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: rule,
                          letterSpacing: 1.0,
                        ),
                  ),
                ),
                if (actionLabel != null)
                  GestureDetector(
                    onTap: onAction,
                    child: Text(
                      actionLabel!.toUpperCase(),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontSize: 11,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
              ],
            ),
          ),
          Padding(padding: contentPadding, child: child),
        ],
      ),
    );
  }
}

/// Kenya flag ribbon — the thin five-band strip used on official headers.
class FlagRibbon extends StatelessWidget {
  final double height;
  const FlagRibbon({super.key, this.height = 4});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: const Row(
        // Stretch forces each band to the strip's full height (a childless
        // ColoredBox otherwise collapses to zero under loose constraints).
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: ColoredBox(color: AppColors.primaryLight)),
          Expanded(child: ColoredBox(color: Color(0xFFCC0000))),
          Expanded(child: ColoredBox(color: AppColors.kenyaBlack)),
          Expanded(child: ColoredBox(color: Color(0xFFCC0000))),
          Expanded(child: ColoredBox(color: AppColors.primaryLight)),
        ],
      ),
    );
  }
}

/// Table-style label/value row used in official info cards.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const InfoRow(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF0F0F0))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textMuted,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
