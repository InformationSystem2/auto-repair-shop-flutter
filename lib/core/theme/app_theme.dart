import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Tokens (theme-aware helpers) ──────────────────────────────────────
// Use these ONLY in widget contexts where Theme.of(context) is unavailable.
// Prefer Theme.of(context).colorScheme.xxx everywhere else.

class AppColors {
  // Brand accent (Indigo)
  static const accent       = Color(0xFF6366F1);
  static const accentDark   = Color(0xFF818CF8);
  static const accentLight  = Color(0xFFEEF2FF);

  // Semantic
  static const success = Color(0xFF22C55E);
  static const danger  = Color(0xFFEF4444);
  static const warning = Color(0xFFF59E0B);
  static const info    = Color(0xFF3B82F6);

  // Light palette
  static const lightBg      = Color(0xFFF8FAFC);
  static const lightSurface = Color(0xFFFFFFFF);
  static const lightBorder  = Color(0xFFE2E8F0);
  static const lightText    = Color(0xFF0F172A);
  static const lightSubtext = Color(0xFF64748B);
  static const lightMuted   = Color(0xFF94A3B8);

  // Dark palette
  static const darkBg      = Color(0xFF0F172A);
  static const darkSurface = Color(0xFF1E293B);
  static const darkBorder  = Color(0xFF334155);
  static const darkText    = Color(0xFFF1F5F9);
  static const darkSubtext = Color(0xFF94A3B8);
  static const darkMuted   = Color(0xFF64748B);
}

// ─── AppTheme ─────────────────────────────────────────────────────────────────

class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary) {
    return GoogleFonts.interTextTheme().copyWith(
      headlineLarge:  GoogleFonts.inter(fontWeight: FontWeight.w900, color: primary,   fontSize: 32),
      headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w800, color: primary,   fontSize: 24),
      titleLarge:     GoogleFonts.inter(fontWeight: FontWeight.w700, color: primary,   fontSize: 20),
      titleMedium:    GoogleFonts.inter(fontWeight: FontWeight.w600, color: primary,   fontSize: 16),
      bodyLarge:      GoogleFonts.inter(fontWeight: FontWeight.w400, color: primary,   fontSize: 16),
      bodyMedium:     GoogleFonts.inter(fontWeight: FontWeight.w400, color: secondary, fontSize: 14),
      bodySmall:      GoogleFonts.inter(fontWeight: FontWeight.w400, color: secondary, fontSize: 12),
      labelLarge:     GoogleFonts.inter(fontWeight: FontWeight.w700, color: primary,   fontSize: 13, letterSpacing: 0.6),
    );
  }

  // ── Light ──────────────────────────────────────────────────────────────────

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.light,
    ).copyWith(
      primary:               AppColors.accent,
      onPrimary:             Colors.white,
      secondary:             AppColors.accent,
      surface:               AppColors.lightSurface,
      onSurface:             AppColors.lightText,
      surfaceContainerLow:   AppColors.lightSurface,
      surfaceContainerHigh:  AppColors.lightBg,
      outline:               AppColors.lightBorder,
      error:                 AppColors.danger,
      onError:               Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.lightBg,
    textTheme:  _textTheme(AppColors.lightText, AppColors.lightSubtext),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.lightSurface,
      foregroundColor: AppColors.lightText,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.lightText,
      ),
    ),
    inputDecorationTheme: _inputTheme(
      fill: AppColors.lightBg,
      border: AppColors.lightBorder,
      accent: AppColors.accent,
    ),
    elevatedButtonTheme: _elevatedBtnTheme(AppColors.accent),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.lightSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.lightBorder),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.lightBorder, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.lightSurface,
      indicatorColor: AppColors.accentLight,
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.lightText,
      contentTextStyle: GoogleFonts.inter(color: Colors.white, fontSize: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.accent,
      brightness: Brightness.dark,
    ).copyWith(
      primary:               AppColors.accentDark,
      onPrimary:             Colors.white,
      secondary:             AppColors.accentDark,
      surface:               AppColors.darkSurface,
      onSurface:             AppColors.darkText,
      surfaceContainerLow:   AppColors.darkSurface,
      surfaceContainerHigh:  AppColors.darkBg,
      outline:               AppColors.darkBorder,
      error:                 AppColors.danger,
      onError:               Colors.white,
    ),
    scaffoldBackgroundColor: AppColors.darkBg,
    textTheme:  _textTheme(AppColors.darkText, AppColors.darkSubtext),
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      backgroundColor: AppColors.darkSurface,
      foregroundColor: AppColors.darkText,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: GoogleFonts.inter(
        fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText,
      ),
    ),
    inputDecorationTheme: _inputTheme(
      fill: AppColors.darkBg,
      border: AppColors.darkBorder,
      accent: AppColors.accentDark,
    ),
    elevatedButtonTheme: _elevatedBtnTheme(AppColors.accentDark),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: AppColors.darkBorder),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.accentDark,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.darkBorder, thickness: 1),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: AppColors.darkSurface,
      indicatorColor: AppColors.accent.withOpacity(0.2),
      labelTextStyle: WidgetStateProperty.all(
        GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkText),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AppColors.darkSurface,
      contentTextStyle: GoogleFonts.inter(color: AppColors.darkText, fontSize: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: AppColors.darkBorder),
      ),
    ),
  );

  // ── Shared helpers ─────────────────────────────────────────────────────────

  static InputDecorationTheme _inputTheme({
    required Color fill,
    required Color border,
    required Color accent,
  }) {
    return InputDecorationTheme(
      filled: true,
      fillColor: fill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: border, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: accent, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.danger, width: 2),
      ),
      hintStyle: GoogleFonts.inter(color: border.withOpacity(0.5), fontSize: 14),
      labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 11, letterSpacing: 0.8),
    );
  }

  static ElevatedButtonThemeData _elevatedBtnTheme(Color accent) {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
