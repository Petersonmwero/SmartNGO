import 'package:flutter/material.dart';

import '../theme.dart';

/// Reusable visual tokens shared by every screen — official eCitizen-style
/// decorations that ThemeData cannot express directly. Use these instead of
/// re-declaring per-screen so the whole app stays on one visual system.
abstract final class AppThemeData {
  // ── Gradients (kept subtle for the official look) ──────────────────────
  static const headerGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [AppColors.primary, AppColors.primaryDark],
  );

  // ── Shadows ────────────────────────────────────────────────────────────
  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.04),
      blurRadius: 4,
      offset: const Offset(0, 1),
    ),
  ];

  static final headerShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.12),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  // ── Decorations ────────────────────────────────────────────────────────
  static final cardDecoration = BoxDecoration(
    color: Colors.white,
    border: Border.all(color: AppColors.border),
    borderRadius: BorderRadius.circular(4),
    boxShadow: cardShadow,
  );

  /// Flat content sheet (legacy name kept for screens that overlap headers).
  static const overlapSheetDecoration = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(8),
      topRight: Radius.circular(8),
    ),
  );

  /// Uniform official input decoration for forms that build decorations in
  /// code (the global InputDecorationTheme already covers plain fields).
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.borderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(2),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    );
  }
}
