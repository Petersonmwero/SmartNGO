import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// eCitizen-inspired official palette: Kenya Government green + gold on
/// clean white surfaces. Legacy constant names (primaryMid, accentLight,
/// charcoal, muted, tints…) are kept as aliases so every screen adopts the
/// palette without per-screen edits.
abstract final class AppColors {
  // Primary — Kenya Government Green
  static const primary = Color(0xFF006633);
  static const primaryDark = Color(0xFF004D26);
  static const primaryLight = Color(0xFF008040);
  static const primarySurface = Color(0xFFE8F5EE);
  static const primaryMid = primaryLight; // legacy alias

  // Accent — Kenya Gold
  static const accent = Color(0xFFCC9900);
  static const accentLight = Color(0xFFFFCC00);
  static const accentSurface = Color(0xFFFFF8E1);

  // Kenya flag colours (decorative ribbon).
  static const kenyaRed = Color(0xFFBB0000);
  static const kenyaBlack = Color(0xFF000000);

  // Neutrals — clean official.
  static const background = Color(0xFFF5F5F5);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceVariant = Color(0xFFF8F8F8);
  static const border = Color(0xFFDDDDDD);
  static const borderStrong = Color(0xFFBBBBBB);
  static const secondary = primaryLight; // legacy alias

  // Text.
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF555555);
  static const textMuted = Color(0xFF888888);
  static const charcoal = textPrimary; // legacy alias
  static const muted = textMuted; // legacy alias

  // Status accents for list/card bars.
  static const statusActive = Color(0xFF006633);
  static const statusCompleted = Color(0xFF0055AA);
  static const statusOnHold = Color(0xFFCC0000);
  static const statusCancelled = Color(0xFF666666);
  static const statusPlanning = Color(0xFFCC7700);

  static const error = Color(0xFFCC0000);

  // Status pill palette: foreground + surface pairs (official style).
  static const success = Color(0xFF006633);
  static const successTint = Color(0xFFE8F5EE);
  static const warning = Color(0xFFCC7700);
  static const warningTint = Color(0xFFFFF3E0);
  static const danger = Color(0xFFCC0000);
  static const dangerTint = Color(0xFFFFEBEE);
  static const info = Color(0xFF0055AA);
  static const infoTint = Color(0xFFE3F2FD);
  static const neutral = Color(0xFF666666);
  static const neutralTint = Color(0xFFEEEEEE);
}

ThemeData buildAppTheme() {
  const primary = AppColors.primary;

  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primarySurface,
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    secondaryContainer: AppColors.accentSurface,
    onSecondaryContainer: Color(0xFF664D00),
    tertiary: AppColors.info,
    onTertiary: Colors.white,
    tertiaryContainer: AppColors.infoTint,
    onTertiaryContainer: Color(0xFF002B55),
    error: AppColors.error,
    onError: Colors.white,
    errorContainer: AppColors.dangerTint,
    onErrorContainer: Color(0xFF660000),
    surface: Colors.white,
    onSurface: AppColors.textPrimary,
    surfaceContainerHighest: Color(0xFFEEEEEE),
    onSurfaceVariant: AppColors.textSecondary,
    outline: AppColors.borderStrong,
    outlineVariant: AppColors.border,
    scrim: Colors.black,
    inverseSurface: Color(0xFF2F312C),
    onInverseSurface: Color(0xFFF0F1EA),
    inversePrimary: Color(0xFF7BD8A8),
    shadow: Colors.black,
    surfaceTint: Colors.transparent,
  );

  // Official single-family typography: Inter everywhere.
  final font = GoogleFonts.inter;

  final textTheme = TextTheme(
    displayLarge: font(fontSize: 57, fontWeight: FontWeight.w700),
    displayMedium: font(fontSize: 45, fontWeight: FontWeight.w700),
    displaySmall: font(fontSize: 36, fontWeight: FontWeight.w700),
    headlineLarge: font(fontSize: 32, fontWeight: FontWeight.w700),
    headlineMedium: font(fontSize: 28, fontWeight: FontWeight.w700),
    headlineSmall: font(fontSize: 22, fontWeight: FontWeight.w700),
    titleLarge: font(fontSize: 20, fontWeight: FontWeight.w700, letterSpacing: 0.2),
    titleMedium: font(fontSize: 15, fontWeight: FontWeight.w600),
    titleSmall: font(fontSize: 13, fontWeight: FontWeight.w600),
    bodyLarge: font(fontSize: 15, color: AppColors.textPrimary),
    bodyMedium: font(fontSize: 14, height: 1.5, color: AppColors.textSecondary),
    bodySmall: font(fontSize: 12, color: AppColors.textSecondary),
    labelLarge: font(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
    labelMedium: font(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.3),
    labelSmall: font(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.3),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: colorScheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: textTheme,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: font(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
          color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
      // Official gold rule under every AppBar.
      shape: const Border(
        bottom: BorderSide(color: AppColors.accent, width: 2),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.borderStrong)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.borderStrong)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.error)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(2),
          borderSide: const BorderSide(color: AppColors.error, width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: font(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500),
      helperStyle: font(fontSize: 11, color: AppColors.textMuted),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: font(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        elevation: 1,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: font(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        elevation: 1,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
        textStyle: font(
            fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: font(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: const BorderSide(color: AppColors.border),
      ),
      labelStyle: font(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AppColors.primarySurface,
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary);
        }
        return const IconThemeData(color: AppColors.textMuted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return font(
              fontSize: 12, fontWeight: FontWeight.w600, color: primary);
        }
        return font(fontSize: 12, color: AppColors.textMuted);
      }),
      elevation: 8,
      height: 68,
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: primary,
      linearTrackColor: AppColors.border,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
    ),
    tabBarTheme: TabBarThemeData(
      labelStyle: font(fontSize: 13, fontWeight: FontWeight.w700),
      unselectedLabelStyle: font(fontSize: 13),
      labelColor: primary,
      unselectedLabelColor: AppColors.textMuted,
      indicatorColor: AppColors.accent,
      dividerColor: AppColors.border,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: primary,
      contentTextStyle: font(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      backgroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
      ),
    ),
  );
}
