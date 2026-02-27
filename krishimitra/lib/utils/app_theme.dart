import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Worm Moon Color Palette - Fresh & Farmer-friendly
  static const Color primaryGreen = Color(
    0xFFa6cf4f,
  ); // #a6cf4f - Vibrant green
  static const Color lightGreen = Color(0xFFbcdb7b); // #bcdb7b - Light green
  static const Color paleGreen = Color(
    0xFFd3e7a7,
  ); // #d3e7a7 - Very light green
  static const Color veryPaleGreen = Color(0xFFe9f3d3); // #e9f3d3 - Pale green
  static const Color white = Color(0xFFffffff); // #ffffff - White

  // Supporting colors
  static const Color darkGreen = Color(0xFF7aa82b); // Darker shade for contrast
  static const Color mediumGreen = Color(0xFF94c352); // Medium shade

  // Accent / highlight
  static const Color amber = Color(0xFFF4A823);
  static const Color amberLight = Color(0xFFFFF0C8);

  // Neutrals
  static const Color earthBrown = Color(0xFF5D4037);
  static const Color darkBrown = Color(0xFF1C1C1E);
  static const Color lightBg = Color(0xFFf8fdf5); // Slight green tint
  static const Color cardBg = Color(0xFFFFFFFF);
  static const Color navBg = Color(0xFFFFFFFF); // White nav for clarity

  // Semantic
  static const Color alertRed = Color(0xFFD62828);
  static const Color warningOrange = Color(0xFFF77F00);
  static const Color successGreen = Color(0xFFa6cf4f); // Use palette green
  static const Color accentGreen = Color(0xFF7aa82b);

  // ── Theme ──────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryGreen,
      scaffoldBackgroundColor: lightBg,
      colorScheme: const ColorScheme.light(
        primary: primaryGreen,
        secondary: mediumGreen,
        tertiary: amber,
        surface: cardBg,
        error: alertRed,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: darkBrown,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: white,
        selectedItemColor: primaryGreen,
        unselectedItemColor: Colors.grey[400],
        elevation: 8,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: GoogleFonts.poppins(
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        color: cardBg,
        shadowColor: Colors.black12,
        surfaceTintColor: Colors.transparent,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: primaryGreen, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600]),
        hintStyle: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[400]),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.poppins(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: darkBrown,
        ),
        displayMedium: GoogleFonts.poppins(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: darkBrown,
        ),
        titleLarge: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: darkBrown,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: darkBrown,
        ),
        bodyLarge: GoogleFonts.poppins(fontSize: 15, color: darkBrown),
        bodyMedium: GoogleFonts.poppins(fontSize: 13, color: Color(0xFF555555)),
        labelSmall: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryGreen,
          side: const BorderSide(color: primaryGreen, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: primaryGreen,
        foregroundColor: Colors.white,
        elevation: 4,
        shape: CircleBorder(),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryGreen,
        inactiveTrackColor: Colors.grey[200],
        thumbColor: primaryGreen,
        overlayColor: primaryGreen.withOpacity(0.15),
        valueIndicatorColor: primaryGreen,
        trackHeight: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: paleGreen,
        selectedColor: primaryGreen,
        labelStyle: GoogleFonts.poppins(fontSize: 12, color: darkBrown),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF0F0F0),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // ── Decoration helpers ────────────────────────────────────────────────────
  static BoxDecoration alertCardDecoration(bool isAlert) {
    return BoxDecoration(
      color:
          isAlert ? alertRed.withOpacity(0.08) : successGreen.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color:
            isAlert ? alertRed.withOpacity(0.4) : successGreen.withOpacity(0.4),
        width: 1.5,
      ),
    );
  }

  static BoxDecoration weatherCardDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [primaryGreen, mediumGreen],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    );
  }

  static BoxDecoration headerDecoration() {
    return const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [darkGreen, primaryGreen],
      ),
      borderRadius: BorderRadius.only(
        bottomLeft: Radius.circular(32),
        bottomRight: Radius.circular(32),
      ),
    );
  }

  static BoxDecoration featureCardDecoration(List<Color> colors) {
    return BoxDecoration(
      gradient: LinearGradient(
        colors: colors,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(20),
      boxShadow: [
        BoxShadow(
          color: colors.first.withOpacity(0.3),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );
  }

  static BoxDecoration statBoxDecoration() {
    return BoxDecoration(
      color: Colors.white.withOpacity(0.18),
      borderRadius: BorderRadius.circular(12),
    );
  }
}
