import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

/// Centralized text styles for elements that repeat across screens.
///
/// The app's fonts are loaded through google_fonts (no bundled font assets),
/// so these are built with GoogleFonts rather than raw fontFamily strings.
/// Prefer Theme.of(context).textTheme for standard slots; use these for the
/// specific recurring roles below.
final class AppTextStyles {
  AppTextStyles._();

  // ── Display (Space Grotesk) ────────────────────────────────────────────
  static final screenTitle = GoogleFonts.spaceGrotesk(
      fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white);

  static final greeting = GoogleFonts.spaceGrotesk(
      fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white);

  static final sectionTitle = GoogleFonts.spaceGrotesk(
      fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.charcoal);

  static final cardTitle = GoogleFonts.spaceGrotesk(
      fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.charcoal);

  // ── Body (Inter) ───────────────────────────────────────────────────────
  static final body =
      GoogleFonts.inter(fontSize: 14, color: const Color(0xFF3A3A3C));

  static final caption =
      GoogleFonts.inter(fontSize: 12, color: const Color(0xFF6B7280));

  static final label = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: const Color(0xFF6B7280));

  /// Grey uppercase section label ("ACCOUNT INFORMATION").
  static final capsLabel = GoogleFonts.inter(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      letterSpacing: 0.8,
      color: const Color(0xFF6B7280));

  // ── Numbers (KPIs) ─────────────────────────────────────────────────────
  static final kpiNumber = GoogleFonts.spaceGrotesk(
      fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.accent);

  // ── Buttons ────────────────────────────────────────────────────────────
  static final buttonText = GoogleFonts.spaceGrotesk(
      fontSize: 15, fontWeight: FontWeight.w600, color: Colors.white);
}
