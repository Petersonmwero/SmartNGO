import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const primary = Color(0xFF0D4A2F);
  static const accent = Color(0xFFE8A020);
  static const secondary = Color(0xFF7BAF7A);
  static const background = Color(0xFFF7F5F0);

  static const statusActive = Color(0xFF2E7D32);
  static const statusCompleted = Color(0xFF1565C0);
  static const statusOnHold = Color(0xFFE65100);
  static const statusCancelled = Color(0xFFC62828);
  static const statusPlanning = Color(0xFF546E7A);

  static const muted = Color(0xFF73796E);
  static const border = Color(0xFFE3E6E0);
}

ThemeData buildAppTheme() {
  const primary = AppColors.primary;

  const colorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: primary,
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFB7E4C7),
    onPrimaryContainer: Color(0xFF002111),
    secondary: AppColors.secondary,
    onSecondary: Colors.white,
    secondaryContainer: Color(0xFFD8F3D6),
    onSecondaryContainer: Color(0xFF1D3620),
    tertiary: AppColors.accent,
    onTertiary: Colors.white,
    tertiaryContainer: Color(0xFFFFE0A0),
    onTertiaryContainer: Color(0xFF3D2700),
    error: Color(0xFFD32F2F),
    onError: Colors.white,
    errorContainer: Color(0xFFFFDAD6),
    onErrorContainer: Color(0xFF410002),
    surface: Colors.white,
    onSurface: Color(0xFF1A1C18),
    surfaceContainerHighest: Color(0xFFE1E4DC),
    onSurfaceVariant: Color(0xFF43483F),
    outline: Color(0xFF73796E),
    outlineVariant: Color(0xFFC3C8BC),
    scrim: Colors.black,
    inverseSurface: Color(0xFF2F312C),
    onInverseSurface: Color(0xFFF0F1EA),
    inversePrimary: Color(0xFF6CDEAB),
    shadow: Colors.black,
    surfaceTint: primary,
  );

  final headingFont = GoogleFonts.spaceGrotesk;
  final bodyFont = GoogleFonts.inter;

  final textTheme = TextTheme(
    displayLarge: headingFont(fontSize: 57, fontWeight: FontWeight.w700, letterSpacing: -0.25),
    displayMedium: headingFont(fontSize: 45, fontWeight: FontWeight.w700),
    displaySmall: headingFont(fontSize: 36, fontWeight: FontWeight.w600),
    headlineLarge: headingFont(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineMedium: headingFont(fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    headlineSmall: headingFont(fontSize: 24, fontWeight: FontWeight.w600),
    titleLarge: headingFont(fontSize: 22, fontWeight: FontWeight.w600),
    titleMedium: headingFont(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.15),
    titleSmall: headingFont(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    bodyLarge: bodyFont(fontSize: 16, letterSpacing: 0.5),
    bodyMedium: bodyFont(fontSize: 14, letterSpacing: 0.25),
    bodySmall: bodyFont(fontSize: 12, letterSpacing: 0.4),
    labelLarge: bodyFont(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
    labelMedium: bodyFont(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: 0.5),
    labelSmall: bodyFont(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
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
      titleTextStyle: headingFont(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white),
      iconTheme: const IconThemeData(color: Colors.white),
      actionsIconTheme: const IconThemeData(color: Colors.white),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCED4CA))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFCED4CA))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: primary, width: 2)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD32F2F))),
      focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFFD32F2F), width: 2)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: bodyFont(fontSize: 14, color: const Color(0xFF43483F)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: bodyFont(fontSize: 15, fontWeight: FontWeight.w600),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primary,
        minimumSize: const Size.fromHeight(46),
        side: const BorderSide(color: primary, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: bodyFont(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primary,
        textStyle: bodyFont(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: bodyFont(fontSize: 13, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 4,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: primary.withValues(alpha: 0.14),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: primary);
        }
        return const IconThemeData(color: AppColors.muted);
      }),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return bodyFont(fontSize: 12, fontWeight: FontWeight.w600, color: primary);
        }
        return bodyFont(fontSize: 12, color: AppColors.muted);
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
      labelStyle: headingFont(fontSize: 14, fontWeight: FontWeight.w600),
      unselectedLabelStyle: bodyFont(fontSize: 14),
      labelColor: primary,
      unselectedLabelColor: AppColors.muted,
      indicatorColor: primary,
      dividerColor: Colors.transparent,
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: const Color(0xFF1A1C18),
      contentTextStyle: bodyFont(fontSize: 14, color: Colors.white),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      behavior: SnackBarBehavior.floating,
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      backgroundColor: Colors.white,
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),
  );
}
