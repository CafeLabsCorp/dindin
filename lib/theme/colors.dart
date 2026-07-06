import 'package:flutter/material.dart';

/// Ported 1:1 from the Next.js app's `src/lib/palette.ts`.
class AppPalette {
  AppPalette._();

  static const List<Color> categorical = [
    Color(0xFF2A78D6), // 1 blue
    Color(0xFF1BAF7A), // 2 aqua
    Color(0xFFEDA100), // 3 yellow
    Color(0xFF008300), // 4 green
    Color(0xFF4A3AA7), // 5 violet
    Color(0xFFE34948), // 6 red
    Color(0xFFE87BA4), // 7 magenta
    Color(0xFFEB6834), // 8 orange
  ];

  static const Map<int, Color> sequentialBlue = {
    100: Color(0xFFCDE2FB),
    250: Color(0xFF86B6EF),
    450: Color(0xFF2A78D6),
    600: Color(0xFF184F95),
  };

  static const Color statusGood = Color(0xFF0CA30C);
  static const Color statusWarning = Color(0xFFFAB219);
  static const Color statusSerious = Color(0xFFEC835A);
  static const Color statusCritical = Color(0xFFD03B3B);

  static const Color inkPrimary = Color(0xFF0B0B0B);
  static const Color inkSecondary = Color(0xFF52514E);
  static const Color inkMuted = Color(0xFF898781);
  static const Color inkGrid = Color(0xFFE1E0D9);

  // Light theme surface tokens (from globals.css :root).
  static const Color lightBackground = Color(0xFFF9F9F7);
  static const Color lightSurface = Color(0xFFFCFCFB);
  static const Color lightForeground = Color(0xFF0B0B0B);
  static const Color lightMuted = Color(0xFF52514E);
  static const Color lightSubtle = Color(0xFF898781);
  static const Color lightBorder = Color(0x1A0B0B0B); // rgba(11,11,11,0.1)

  // Dark theme surface tokens (from globals.css prefers-color-scheme: dark).
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF1A1A19);
  static const Color darkForeground = Color(0xFFFFFFFF);
  static const Color darkMuted = Color(0xFFC3C2B7);
  static const Color darkSubtle = Color(0xFF898781);
  static const Color darkBorder = Color(0x1AFFFFFF); // rgba(255,255,255,0.1)
}
