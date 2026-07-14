import 'package:flutter/material.dart';

import 'theme.dart';

/// Green success snackbar with an amber check — the standard confirmation
/// after any successful form submission.
void showSuccessSnackBar(BuildContext context, String message) {
  _showSnackBar(context, message, AppColors.primary,
      const Icon(Icons.check_circle, color: AppColors.accentLight, size: 20));
}

/// Red error snackbar with an alert icon — the standard treatment for
/// failures and validation prompts, so errors never appear on the
/// success-green background the theme uses by default.
void showErrorSnackBar(BuildContext context, String message) {
  _showSnackBar(context, message, AppColors.error,
      const Icon(Icons.error_outline, color: Colors.white, size: 20));
}

void _showSnackBar(
    BuildContext context, String message, Color background, Icon icon) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      backgroundColor: background,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 3),
      content: Row(
        children: [
          icon,
          const SizedBox(width: 8),
          Expanded(
            child:
                Text(message, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    ),
  );
}
