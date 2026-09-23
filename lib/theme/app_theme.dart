import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Soft sky desk palette: ink navy, cool mist, mint action.
class AppColors {
  static const ink = Color(0xFF1A2332);
  static const mist = Color(0xFFE6EDF4);
  static const paper = Color(0xFFF7FAFC);
  static const mint = Color(0xFF1F7A6B);
  static const mintDeep = Color(0xFF15574C);
  static const sky = Color(0xFF3D6B9A);
  static const line = Color(0xFFCDD8E3);
  static const danger = Color(0xFFA33B3B);
  static const muted = Color(0xFF5E6E80);
  static const bubbleMine = Color(0xFF1F7A6B);
  static const bubbleTheirs = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.mist,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.mint,
        primary: AppColors.mint,
        secondary: AppColors.sky,
        surface: AppColors.paper,
        error: AppColors.danger,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme).copyWith(
        displaySmall: GoogleFonts.fraunces(
          fontSize: 34,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
          height: 1.12,
        ),
        headlineMedium: GoogleFonts.fraunces(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleLarge: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        titleMedium: GoogleFonts.dmSans(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
        bodyLarge: GoogleFonts.dmSans(
          fontSize: 16,
          height: 1.45,
          color: AppColors.ink,
        ),
        bodyMedium: GoogleFonts.dmSans(
          fontSize: 14,
          height: 1.45,
          color: AppColors.ink,
        ),
        labelLarge: GoogleFonts.dmSans(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.15,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.mist,
        foregroundColor: AppColors.ink,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: GoogleFonts.fraunces(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.paper,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.mint, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.mint,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: GoogleFonts.dmSans(color: Colors.white),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
