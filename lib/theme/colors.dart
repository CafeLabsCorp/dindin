import 'package:flutter/material.dart';

/// "Envelope caloroso" identity — hand-tuned tokens from `docs/DESIGN.md`
/// (§1), replacing the old blue Material-seed palette ported 1:1 from the
/// Next.js app.
class AppPalette {
  AppPalette._();

  /// 8-color categorical palette (per-caixinha color identity), §1.3.
  /// Light variant.
  static const List<Color> categorical = [
    Color(0xFF2E6F4D), // 1 Verde Cofre
    Color(0xFFC1502E), // 2 Terracota
    Color(0xFFA8660A), // 3 Âmbar
    Color(0xFF2E6B78), // 4 Azul Petróleo
    Color(0xFF7A4A6B), // 5 Ameixa
    Color(0xFFA23B3B), // 6 Vinho
    Color(0xFF7C7A3A), // 7 Oliva
    Color(0xFFB97064), // 8 Argila Rosada
  ];

  /// Same 8 categories, dark-theme variant.
  static const List<Color> categoricalDark = [
    Color(0xFF5FAE80), // 1 Verde Cofre
    Color(0xFFE2896A), // 2 Terracota
    Color(0xFFE0A542), // 3 Âmbar
    Color(0xFF4E96A3), // 4 Azul Petróleo
    Color(0xFFA87CA0), // 5 Ameixa
    Color(0xFFD06868), // 6 Vinho
    Color(0xFFACA85C), // 7 Oliva
    Color(0xFFD69C90), // 8 Argila Rosada
  ];

  // --- Light theme tokens (§1.1) ---
  static const Color lightPrimary = Color(0xFF2E6F4D);
  static const Color lightOnPrimary = Color(0xFFFFFFFF);
  static const Color lightPrimaryContainer = Color(0xFFD7EBDD);
  static const Color lightOnPrimaryContainer = Color(0xFF14392A);

  static const Color lightSecondary = Color(0xFF6B7A5E);
  static const Color lightOnSecondary = Color(0xFFFFFFFF);
  static const Color lightSecondaryContainer = Color(0xFFE1E8D8);
  static const Color lightOnSecondaryContainer = Color(0xFF2B3320);

  static const Color lightTertiary = Color(0xFFC1502E);
  static const Color lightOnTertiary = Color(0xFFFFFFFF);
  static const Color lightTertiaryContainer = Color(0xFFF7DCCF);
  static const Color lightOnTertiaryContainer = Color(0xFF5C2413);

  static const Color lightError = Color(0xFFC13B3B);
  static const Color lightOnError = Color(0xFFFFFFFF);
  static const Color lightErrorContainer = Color(0xFFF9D9D6);
  static const Color lightOnErrorContainer = Color(0xFF5C1616);

  static const Color lightBackground = Color(0xFFFAF4EA); // scaffold canvas
  static const Color lightSurface = Color(0xFFFFFFFF); // cards
  static const Color lightSurfaceElevated = Color(0xFFFFFFFF); // dialogs/sheets/menus

  static const Color lightInkPrimary = Color(0xFF211A12);
  static const Color lightInkSecondary = Color(0xFF5C5346);
  static const Color lightInkSubtle = Color(0xFF746A5D);

  static const Color lightBorder = Color(0x1F211A12); // inkPrimary @ 12%
  static const Color lightOutline = Color(0xFF8A7F6E); // opaque, for real component outlines

  static const Color lightStatusGood = Color(0xFF2F7D3B);
  static const Color lightStatusWarning = Color(0xFFA8660A);
  static const Color lightStatusCritical = Color(0xFFC13B3B);

  // --- Dark theme tokens (§1.2) ---
  static const Color darkPrimary = Color(0xFF7FCB9E);
  static const Color darkOnPrimary = Color(0xFF0D3320);
  static const Color darkPrimaryContainer = Color(0xFF1F4732);
  static const Color darkOnPrimaryContainer = Color(0xFFBEE8CE);

  static const Color darkSecondary = Color(0xFFA9B896);
  static const Color darkOnSecondary = Color(0xFF24301C);
  static const Color darkSecondaryContainer = Color(0xFF333D26);
  static const Color darkOnSecondaryContainer = Color(0xFFDCE6C9);

  static const Color darkTertiary = Color(0xFFF0916A);
  static const Color darkOnTertiary = Color(0xFF431507);
  static const Color darkTertiaryContainer = Color(0xFF4A2417);
  static const Color darkOnTertiaryContainer = Color(0xFFF7CDBB);

  static const Color darkError = Color(0xFFE8746A);
  static const Color darkOnError = Color(0xFF431010);
  static const Color darkErrorContainer = Color(0xFF4A1B1B);
  static const Color darkOnErrorContainer = Color(0xFFF7CFC9);

  static const Color darkBackground = Color(0xFF16130F);
  static const Color darkSurface = Color(0xFF201C17);
  static const Color darkSurfaceElevated = Color(0xFF2A241D);

  static const Color darkInkPrimary = Color(0xFFF5F1EA);
  static const Color darkInkSecondary = Color(0xFFC9C2B4);
  static const Color darkInkSubtle = Color(0xFFA79C89);

  static const Color darkBorder = Color(0x1FF5F1EA); // inkPrimary @ 12%
  static const Color darkOutline = Color(0xFF6B6455); // opaque, for real component outlines

  static const Color darkStatusGood = Color(0xFF6FCB82);
  static const Color darkStatusWarning = Color(0xFFE0A542);
  static const Color darkStatusCritical = Color(0xFFE8746A);
}
