import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Paper desk palette: warm stock, ink type, one vermilion signal.
class AppColors {
  static const paper = Color(0xFFF3EFE6);
  static const card = Color(0xFFFBF9F4);
  static const sunken = Color(0xFFEAE4D8);
  static const ink = Color(0xFF17150F);
  static const inkSoft = Color(0xFF3B372E);
  static const muted = Color(0xFF7A7366);
  static const faint = Color(0xFFA59D8E);
  static const line = Color(0xFFE0D9CB);
  static const lineStrong = Color(0xFFCBC2B0);

  static const signal = Color(0xFFE2552D);
  static const signalSoft = Color(0xFFF8DDD2);
  static const sage = Color(0xFF2F6B55);
  static const sageSoft = Color(0xFFDCE8E0);
  static const amber = Color(0xFF9A6412);
  static const amberSoft = Color(0xFFF4E4C4);
  static const danger = Color(0xFFB3261E);
  static const dangerSoft = Color(0xFFF6D9D6);

  static const avatarTones = [
    Color(0xFFD9C6A5),
    Color(0xFFC9D6C4),
    Color(0xFFE4C2B4),
    Color(0xFFC8CDD9),
    Color(0xFFE2D39B),
    Color(0xFFD5C3D6),
  ];
}

class AppType {
  static TextStyle display(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w700,
        height: 1.05,
        letterSpacing: -size * 0.03,
        color: color,
      );

  static TextStyle heading(double size, {Color color = AppColors.ink}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: size,
        fontWeight: FontWeight.w600,
        height: 1.2,
        letterSpacing: -size * 0.015,
        color: color,
      );

  static TextStyle body(
    double size, {
    Color color = AppColors.ink,
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
  }) => GoogleFonts.instrumentSans(
    fontSize: size,
    fontWeight: weight,
    height: height,
    color: color,
  );

  /// Metadata: timestamps, counters, small caps labels.
  static TextStyle mono(
    double size, {
    Color color = AppColors.muted,
    FontWeight weight = FontWeight.w500,
    double spacing = 0.4,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: size,
    fontWeight: weight,
    letterSpacing: spacing,
    color: color,
  );
}

class AppTheme {
  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.signal,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.ink,
          onPrimary: AppColors.card,
          secondary: AppColors.signal,
          onSecondary: Colors.white,
          surface: AppColors.card,
          onSurface: AppColors.ink,
          surfaceContainerLowest: AppColors.card,
          surfaceContainerLow: AppColors.card,
          surfaceContainer: AppColors.paper,
          surfaceContainerHigh: AppColors.card,
          surfaceContainerHighest: AppColors.sunken,
          outline: AppColors.lineStrong,
          outlineVariant: AppColors.line,
          error: AppColors.danger,
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.paper,
      splashFactory: InkRipple.splashFactory,
    );

    final text = GoogleFonts.instrumentSansTextTheme(base.textTheme)
        .apply(bodyColor: AppColors.ink, displayColor: AppColors.ink);

    final buttonShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      textTheme: text.copyWith(
        displaySmall: AppType.display(36),
        headlineMedium: AppType.heading(26),
        titleLarge: AppType.heading(20),
        titleMedium: AppType.body(16, weight: FontWeight.w600),
        bodyLarge: AppType.body(16),
        bodyMedium: AppType.body(14),
        labelLarge: AppType.body(15, weight: FontWeight.w600),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.paper,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: 4,
        systemOverlayStyle: SystemUiOverlayStyle.dark,
        titleTextStyle: AppType.heading(18),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.line,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.card,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        hintStyle: AppType.body(15, color: AppColors.faint),
        labelStyle: AppType.body(15, color: AppColors.muted),
        floatingLabelStyle: AppType.body(14, color: AppColors.ink),
        helperStyle: AppType.body(12, color: AppColors.muted),
        errorStyle: AppType.body(12, color: AppColors.danger),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.4),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.ink,
          foregroundColor: AppColors.card,
          disabledBackgroundColor: AppColors.sunken,
          disabledForegroundColor: AppColors.faint,
          minimumSize: const Size(48, 50),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          shape: buttonShape,
          textStyle: AppType.body(15, weight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.ink,
          minimumSize: const Size(48, 46),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          side: const BorderSide(color: AppColors.lineStrong),
          shape: buttonShape,
          textStyle: AppType.body(14, weight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.ink,
          shape: buttonShape,
          textStyle: AppType.body(14, weight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.sunken,
        indicatorShape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
        height: 64,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppType.body(
            12,
            weight: FontWeight.w600,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 22,
            color: states.contains(WidgetState.selected)
                ? AppColors.ink
                : AppColors.muted,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: AppColors.lineStrong,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        titleTextStyle: AppType.heading(20),
        contentTextStyle: AppType.body(15, color: AppColors.inkSoft),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.line),
        ),
        textStyle: AppType.body(14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.ink,
        contentTextStyle: AppType.body(14, color: AppColors.card),
        actionTextColor: AppColors.signalSoft,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.ink,
        linearTrackColor: AppColors.sunken,
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? AppColors.ink
              : AppColors.lineStrong,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.ink,
        foregroundColor: AppColors.card,
        elevation: 0,
        highlightElevation: 0,
        extendedTextStyle: AppType.body(15, weight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.ink,
          borderRadius: BorderRadius.circular(8),
        ),
        textStyle: AppType.body(12, color: AppColors.card),
      ),
    );
  }
}
