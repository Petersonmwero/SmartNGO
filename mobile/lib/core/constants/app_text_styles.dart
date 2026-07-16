import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Centralized eCitizen-style text roles. The whole app uses one family
/// (Inter, via google_fonts) for the clean official look; prefer
/// Theme.of(context).textTheme for standard slots and these for the
/// recurring official roles below.
final class AppTextStyles {
  AppTextStyles._();

  static final pageTitle = GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.textPrimary,
      letterSpacing: 0.2);

  /// Green uppercase section heading used in OfficialCard headers.
  static final sectionTitle = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w700,
      color: AppColors.primary,
      letterSpacing: 1.0);

  static final cardTitle = GoogleFonts.inter(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary);

  static final body = GoogleFonts.inter(
      fontSize: 14, height: 1.5, color: AppColors.textSecondary);

  static final caption =
      GoogleFonts.inter(fontSize: 12, color: AppColors.textSecondary);

  static final label = GoogleFonts.inter(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.textMuted,
      letterSpacing: 0.3);

  /// Grey uppercase group label ("ACCOUNT INFORMATION").
  static final capsLabel = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: AppColors.textMuted);

  static final kpiNumber = GoogleFonts.inter(
      fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.primary);

  static final buttonText = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: Colors.white,
      letterSpacing: 0.5);

  // Legacy role names still referenced by screens.
  static final screenTitle = GoogleFonts.inter(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: Colors.white,
      letterSpacing: 0.2);
  static final greeting = GoogleFonts.inter(
      fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white);
}
