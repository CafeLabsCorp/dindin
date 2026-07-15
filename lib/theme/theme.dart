import 'package:flutter/material.dart';
import 'colors.dart';

/// Surface/status tokens that don't map cleanly onto [ColorScheme], mirroring
/// `docs/DESIGN.md` §1. `surface` here is the scaffold canvas ("background"
/// in the design doc — kept as `surface` to avoid a second rename since
/// this extension already shipped with that name).
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color surface;
  final Color muted;
  final Color subtle;
  final Color border;
  final Color statusGood;
  final Color statusWarning;
  final Color statusCritical;

  const AppTokens({
    required this.surface,
    required this.muted,
    required this.subtle,
    required this.border,
    required this.statusGood,
    required this.statusWarning,
    required this.statusCritical,
  });

  static const light = AppTokens(
    surface: AppPalette.lightBackground,
    muted: AppPalette.lightInkSecondary,
    subtle: AppPalette.lightInkSubtle,
    border: AppPalette.lightBorder,
    statusGood: AppPalette.lightStatusGood,
    statusWarning: AppPalette.lightStatusWarning,
    statusCritical: AppPalette.lightStatusCritical,
  );

  static const dark = AppTokens(
    surface: AppPalette.darkBackground,
    muted: AppPalette.darkInkSecondary,
    subtle: AppPalette.darkInkSubtle,
    border: AppPalette.darkBorder,
    statusGood: AppPalette.darkStatusGood,
    statusWarning: AppPalette.darkStatusWarning,
    statusCritical: AppPalette.darkStatusCritical,
  );

  @override
  AppTokens copyWith({
    Color? surface,
    Color? muted,
    Color? subtle,
    Color? border,
    Color? statusGood,
    Color? statusWarning,
    Color? statusCritical,
  }) {
    return AppTokens(
      surface: surface ?? this.surface,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      border: border ?? this.border,
      statusGood: statusGood ?? this.statusGood,
      statusWarning: statusWarning ?? this.statusWarning,
      statusCritical: statusCritical ?? this.statusCritical,
    );
  }

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      surface: Color.lerp(surface, other.surface, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      subtle: Color.lerp(subtle, other.subtle, t)!,
      border: Color.lerp(border, other.border, t)!,
      statusGood: Color.lerp(statusGood, other.statusGood, t)!,
      statusWarning: Color.lerp(statusWarning, other.statusWarning, t)!,
      statusCritical: Color.lerp(statusCritical, other.statusCritical, t)!,
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

const _fraunces = 'Fraunces';
const _workSans = 'Work Sans';

/// Type scale from `docs/DESIGN.md` §2. Line-heights are expressed as
/// Flutter's `height` multiplier (line-height px / font-size px).
TextTheme _textTheme(Color ink) {
  return TextTheme(
    displayLarge: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w400, fontSize: 57, height: 64 / 57, color: ink),
    displayMedium: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w400, fontSize: 45, height: 52 / 45, color: ink),
    displaySmall: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w500, fontSize: 36, height: 44 / 36, color: ink),
    headlineLarge: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w600, fontSize: 32, height: 40 / 32, color: ink),
    headlineMedium: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w600, fontSize: 28, height: 36 / 28, color: ink),
    headlineSmall: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w600, fontSize: 24, height: 32 / 24, color: ink),
    titleLarge: TextStyle(fontFamily: _fraunces, fontWeight: FontWeight.w600, fontSize: 22, height: 28 / 22, color: ink),
    titleMedium: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w600, fontSize: 16, height: 24 / 16, color: ink),
    titleSmall: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w600, fontSize: 14, height: 20 / 14, color: ink),
    bodyLarge: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w400, fontSize: 16, height: 24 / 16, color: ink),
    bodyMedium: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w400, fontSize: 14, height: 20 / 14, color: ink),
    bodySmall: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w400, fontSize: 12, height: 16 / 12, color: ink),
    labelLarge: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w600, fontSize: 14, height: 20 / 14, color: ink),
    labelMedium: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w600, fontSize: 12, height: 16 / 12, color: ink),
    labelSmall: TextStyle(fontFamily: _workSans, fontWeight: FontWeight.w600, fontSize: 11, height: 16 / 11, color: ink),
  );
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppPalette.lightPrimary,
      onPrimary: AppPalette.lightOnPrimary,
      primaryContainer: AppPalette.lightPrimaryContainer,
      onPrimaryContainer: AppPalette.lightOnPrimaryContainer,
      secondary: AppPalette.lightSecondary,
      onSecondary: AppPalette.lightOnSecondary,
      secondaryContainer: AppPalette.lightSecondaryContainer,
      onSecondaryContainer: AppPalette.lightOnSecondaryContainer,
      tertiary: AppPalette.lightTertiary,
      onTertiary: AppPalette.lightOnTertiary,
      tertiaryContainer: AppPalette.lightTertiaryContainer,
      onTertiaryContainer: AppPalette.lightOnTertiaryContainer,
      error: AppPalette.lightError,
      onError: AppPalette.lightOnError,
      errorContainer: AppPalette.lightErrorContainer,
      onErrorContainer: AppPalette.lightOnErrorContainer,
      surface: AppPalette.lightSurface,
      onSurface: AppPalette.lightInkPrimary,
      onSurfaceVariant: AppPalette.lightInkSecondary,
      outline: AppPalette.lightOutline,
      shadow: AppPalette.lightInkPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      textTheme: _textTheme(AppPalette.lightInkPrimary),
      cardTheme: CardThemeData(
        color: AppPalette.lightSurface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.lightBorder),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.lightSurfaceElevated,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.lightSurfaceElevated,
        modalBackgroundColor: AppPalette.lightSurfaceElevated,
        elevation: 3,
        modalElevation: 3,
        surfaceTintColor: Colors.transparent,
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppPalette.lightSurfaceElevated),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(3),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppPalette.lightSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.lightPrimary, width: 2),
        ),
      ),
      dividerColor: AppPalette.lightBorder,
      extensions: const [AppTokens.light],
    );
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppPalette.darkPrimary,
      onPrimary: AppPalette.darkOnPrimary,
      primaryContainer: AppPalette.darkPrimaryContainer,
      onPrimaryContainer: AppPalette.darkOnPrimaryContainer,
      secondary: AppPalette.darkSecondary,
      onSecondary: AppPalette.darkOnSecondary,
      secondaryContainer: AppPalette.darkSecondaryContainer,
      onSecondaryContainer: AppPalette.darkOnSecondaryContainer,
      tertiary: AppPalette.darkTertiary,
      onTertiary: AppPalette.darkOnTertiary,
      tertiaryContainer: AppPalette.darkTertiaryContainer,
      onTertiaryContainer: AppPalette.darkOnTertiaryContainer,
      error: AppPalette.darkError,
      onError: AppPalette.darkOnError,
      errorContainer: AppPalette.darkErrorContainer,
      onErrorContainer: AppPalette.darkOnErrorContainer,
      surface: AppPalette.darkSurface,
      onSurface: AppPalette.darkInkPrimary,
      onSurfaceVariant: AppPalette.darkInkSecondary,
      outline: AppPalette.darkOutline,
      shadow: AppPalette.darkInkPrimary,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      textTheme: _textTheme(AppPalette.darkInkPrimary),
      cardTheme: CardThemeData(
        color: AppPalette.darkSurface,
        elevation: 1,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppPalette.darkBorder),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppPalette.darkSurfaceElevated,
        elevation: 3,
        surfaceTintColor: Colors.transparent,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppPalette.darkSurfaceElevated,
        modalBackgroundColor: AppPalette.darkSurfaceElevated,
        elevation: 3,
        modalElevation: 3,
        surfaceTintColor: Colors.transparent,
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppPalette.darkSurfaceElevated),
          surfaceTintColor: WidgetStatePropertyAll(Colors.transparent),
          elevation: WidgetStatePropertyAll(3),
        ),
      ),
      popupMenuTheme: const PopupMenuThemeData(
        color: AppPalette.darkSurfaceElevated,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppPalette.darkPrimary, width: 2),
        ),
      ),
      dividerColor: AppPalette.darkBorder,
      extensions: const [AppTokens.dark],
    );
  }
}
