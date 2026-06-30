import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFF6366F1); // Indigo 500
  static const Color secondaryColor = Color(0xFF4F46E5); // Indigo 600
  static const Color accentColor = Color(0xFFEC4899); // Pink 500
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A); // Slate 900
  static const Color textSecondary = Color(0xFF64748B); // Slate 500

  // Dark Theme Colors
  static const Color darkBackgroundColor = Color(0xFF0F172A); // Slate 900
  static const Color darkSurfaceColor = Color(0xFF1E293B); // Slate 800
  static const Color darkTextPrimary = Color(0xFFF8FAFC); // Slate 50
  static const Color darkTextSecondary = Color(0xFF94A3B8); // Slate 400

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: backgroundColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: surfaceColor,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme().copyWith(
        displayLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        displayMedium: GoogleFonts.outfit(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: GoogleFonts.outfit(
          color: textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: const TextStyle(color: textPrimary),
        bodyMedium: const TextStyle(color: textSecondary),
      ),
      cardTheme: CardThemeData(
        color: surfaceColor,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.05),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: textPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      scaffoldBackgroundColor: darkBackgroundColor,
      colorScheme: const ColorScheme.dark(
        primary: primaryColor,
        secondary: secondaryColor,
        surface: darkSurfaceColor,
        onPrimary: Colors.white,
        onSurface: darkTextPrimary,
      ),
      textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme)
          .copyWith(
            displayLarge: GoogleFonts.outfit(
              color: darkTextPrimary,
              fontWeight: FontWeight.bold,
            ),
            displayMedium: GoogleFonts.outfit(
              color: darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
            titleLarge: GoogleFonts.outfit(
              color: darkTextPrimary,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: const TextStyle(color: darkTextPrimary),
            bodyMedium: const TextStyle(color: darkTextSecondary),
          ),
      cardTheme: CardThemeData(
        color: darkSurfaceColor,
        elevation: 4,
        shadowColor: Colors.black.withValues(alpha: 0.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: darkTextPrimary),
        titleTextStyle: GoogleFonts.outfit(
          color: darkTextPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      useMaterial3: true,
    );
  }
}
