import 'package:flutter/material.dart';

import '../theme.dart';

/// Reusable visual tokens shared by every screen — gradients, shadows, and
/// decorations that ThemeData cannot express directly. Use these instead of
/// re-declaring per-screen so the whole app stays on one visual system.
abstract final class AppThemeData {
  // ── Gradients ──────────────────────────────────────────────────────────
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primary, AppColors.primaryMid],
  );

  // ── Shadows ────────────────────────────────────────────────────────────
  static final cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.06),
      blurRadius: 10,
      offset: const Offset(0, 3),
    ),
  ];

  static final headerShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.15),
      blurRadius: 12,
      offset: const Offset(0, 4),
    ),
  ];

  // ── Decorations ────────────────────────────────────────────────────────
  static final cardDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    boxShadow: cardShadow,
  );

  /// The 24px-rounded cream sheet that overlaps green headers.
  static const overlapSheetDecoration = BoxDecoration(
    color: AppColors.background,
    borderRadius: BorderRadius.only(
      topLeft: Radius.circular(24),
      topRight: Radius.circular(24),
    ),
  );

  /// Uniform input decoration for forms that build decorations in code
  /// (the global InputDecorationTheme already covers plain label fields).
  static InputDecoration inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
