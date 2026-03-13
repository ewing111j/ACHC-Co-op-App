// lib/utils/app_theme.dart
// Style 3: Minimalist Navy & Gold — ACHC Logo-Inspired
import 'package:flutter/material.dart';

class AppTheme {
  // ── Brand Colors (extracted from ACHC logo) ──────────────────
  static const Color navyDark   = Color(0xFF151E4A);  // darkest navy
  static const Color navy       = Color(0xFF1E2B5E);  // primary navy
  static const Color navyMid    = Color(0xFF2D3E7E);  // mid navy
  static const Color navyLight  = Color(0xFF3D5199);  // light navy tint

  static const Color gold       = Color(0xFFC9A84C);  // primary gold
  static const Color goldLight  = Color(0xFFDDBE6E);  // light gold
  static const Color goldDark   = Color(0xFF9E7C2E);  // dark gold

  // ── Backgrounds ──────────────────────────────────────────────
  static const Color background      = Color(0xFFF8F9FC);
  static const Color surface         = Color(0xFFFFFFFF);
  static const Color surfaceVariant  = Color(0xFFF0F2F8);
  static const Color cardBorder      = Color(0xFFDDE1EE);

  // ── Text ─────────────────────────────────────────────────────
  static const Color textPrimary    = Color(0xFF1E2B5E);   // navy as text
  static const Color textSecondary  = Color(0xFF5A6584);
  static const Color textHint       = Color(0xFFB0B8D0);

  // ── Status ───────────────────────────────────────────────────
  static const Color success  = Color(0xFF2E7D32);
  static const Color warning  = Color(0xFFF9A825);
  static const Color error    = Color(0xFFC62828);
  static const Color info     = Color(0xFF1565C0);

  // ── Assignment Colors ─────────────────────────────────────────
  static const Color mandatoryRed  = Color(0xFFB71C1C);
  static const Color optionalGreen = Color(0xFF2E7D32);

  // ── Feature Tile Colors (navy-tinted variants) ────────────────
  static const Color assignmentsColor = Color(0xFF283593);  // deep indigo-navy
  static const Color messagesColor    = Color(0xFF1E2B5E);  // navy
  static const Color calendarColor    = Color(0xFF2E6B3E);  // forest green
  static const Color photosColor      = Color(0xFF7B1E3E);  // deep rose
  static const Color checkInColor     = Color(0xFFC9A84C);  // gold
  static const Color filesColor       = Color(0xFF5D3A1A);  // dark brown
  static const Color feedsColor       = Color(0xFF1A4A7A);  // dark blue
  static const Color prayerColor      = Color(0xFF4A1942);  // deep purple

  // ── Gradients ────────────────────────────────────────────────
  static const LinearGradient navyGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [navyDark, navy, navyMid],
  );

  static const LinearGradient goldAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.centerRight,
    colors: [goldDark, gold, goldLight],
  );

  // ── Theme Data ────────────────────────────────────────────────
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Georgia',  // serif feel
      colorScheme: ColorScheme.fromSeed(
        seedColor: navy,
        primary: navy,
        secondary: gold,
        surface: surface,
        error: error,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: background,

      appBarTheme: const AppBarTheme(
        backgroundColor: navy,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 19,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          fontFamily: 'Georgia',
        ),
        iconTheme: IconThemeData(color: Colors.white, size: 20),
      ),

      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navy,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: navy,
          side: const BorderSide(color: navy, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: error),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(color: textHint, fontSize: 14),
        labelStyle: const TextStyle(color: textSecondary, fontSize: 14),
      ),

      textTheme: const TextTheme(
        headlineLarge:  TextStyle(color: textPrimary, fontSize: 26, fontWeight: FontWeight.w700, fontFamily: 'Georgia'),
        headlineMedium: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.w600, fontFamily: 'Georgia'),
        headlineSmall:  TextStyle(color: textPrimary, fontSize: 18, fontWeight: FontWeight.w600, fontFamily: 'Georgia'),
        titleLarge:     TextStyle(color: textPrimary, fontSize: 17, fontWeight: FontWeight.w600),
        titleMedium:    TextStyle(color: textPrimary, fontSize: 15, fontWeight: FontWeight.w500),
        bodyLarge:      TextStyle(color: textPrimary, fontSize: 15),
        bodyMedium:     TextStyle(color: textSecondary, fontSize: 13),
        labelLarge:     TextStyle(color: textPrimary, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
      ),

      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),

      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        side: const BorderSide(color: cardBorder),
      ),

      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white60,
        indicatorColor: gold,
        dividerColor: Colors.transparent,
        labelStyle: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        unselectedLabelStyle: TextStyle(fontSize: 13),
      ),

      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: navy,
        unselectedItemColor: textHint,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedLabelStyle: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 11),
      ),
    );
  }

  // ── Shared Decoration Helpers ─────────────────────────────────
  static BoxDecoration get navyHeaderDecoration => const BoxDecoration(
    gradient: navyGradient,
  );

  static BoxDecoration cardDecoration({Color? borderColor}) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: borderColor ?? cardBorder),
  );

  static BoxDecoration featureTileDecoration(Color featureColor) => BoxDecoration(
    color: surface,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: featureColor.withValues(alpha: 0.2)),
    boxShadow: [
      BoxShadow(
        color: featureColor.withValues(alpha: 0.06),
        blurRadius: 10,
        offset: const Offset(0, 3),
      ),
    ],
  );

  // Gold divider widget
  static Widget goldDivider({double indent = 0}) => Padding(
    padding: EdgeInsets.symmetric(horizontal: indent),
    child: Container(
      height: 1,
      decoration: const BoxDecoration(
        gradient: goldAccent,
      ),
    ),
  );

  // Navy section header
  static Widget sectionHeader(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 4, 0, 10),
    child: Row(
      children: [
        Container(width: 3, height: 18, decoration: const BoxDecoration(gradient: goldAccent)),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(
          fontSize: 15, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: 0.3,
        )),
        const Spacer(),
        if (trailing != null) trailing,
      ],
    ),
  );
}
