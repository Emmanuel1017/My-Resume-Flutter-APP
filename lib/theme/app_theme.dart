import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract class AppColors {
  static const bg        = Color(0xFF0D1321);
  static const surface   = Color(0xFF151E2E);
  static const card      = Color(0xFF1A2540);
  static const border    = Color(0xFF253050);
  static const primary   = Color(0xFF5A8C3E);
  static const accent    = Color(0xFFA8E87A);
  static const textHigh  = Color(0xFFE8F5E0);
  static const textMid   = Color(0xFF8AA89E);
  static const textLow   = Color(0xFF4A6058);
  static const danger    = Color(0xFFE05C6A);
  static const warning   = Color(0xFFE0A84A);
}

class AppTheme {
  static ThemeData get dark {
    final base = ThemeData.dark();
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: const ColorScheme.dark(
        primary:   AppColors.primary,
        secondary: AppColors.accent,
        surface:   AppColors.surface,
        error:     AppColors.danger,
      ),
      textTheme: GoogleFonts.montserratTextTheme(base.textTheme).apply(
        bodyColor:    AppColors.textHigh,
        displayColor: AppColors.textHigh,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled:           true,
        fillColor:        AppColors.card,
        border:           OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        enabledBorder:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.border),
        ),
        focusedBorder:    OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:   const BorderSide(color: AppColors.primary, width: 2),
        ),
        labelStyle:       const TextStyle(color: AppColors.textMid),
        hintStyle:        const TextStyle(color: AppColors.textLow),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor:  AppColors.primary,
          foregroundColor:  Colors.white,
          minimumSize:      const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.montserrat(
            fontWeight: FontWeight.w700,
            fontSize:   15,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
