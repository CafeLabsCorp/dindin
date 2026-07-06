import 'package:flutter/material.dart';
import 'colors.dart';

/// Surface tokens that don't map cleanly onto [ColorScheme], mirroring the
/// CSS custom properties in the Next.js app's `globals.css`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color surface;
  final Color muted;
  final Color subtle;
  final Color border;

  const AppTokens({
    required this.surface,
    required this.muted,
    required this.subtle,
    required this.border,
  });

  static const light = AppTokens(
    surface: AppPalette.lightSurface,
    muted: AppPalette.lightMuted,
    subtle: AppPalette.lightSubtle,
    border: AppPalette.lightBorder,
  );

  static const dark = AppTokens(
    surface: AppPalette.darkSurface,
    muted: AppPalette.darkMuted,
    subtle: AppPalette.darkSubtle,
    border: AppPalette.darkBorder,
  );

  @override
  AppTokens copyWith({Color? surface, Color? muted, Color? subtle, Color? border}) {
    return AppTokens(
      surface: surface ?? this.surface,
      muted: muted ?? this.muted,
      subtle: subtle ?? this.subtle,
      border: border ?? this.border,
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
    );
  }
}

extension AppTokensContext on BuildContext {
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;
}

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.categorical[0],
      brightness: Brightness.light,
      surface: AppPalette.lightBackground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.lightBackground,
      textTheme: Typography.material2021().black.apply(fontFamily: 'Roboto'),
      cardTheme: CardThemeData(
        color: AppPalette.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppPalette.lightBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.lightBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPalette.lightBorder),
        ),
      ),
      dividerColor: AppPalette.lightBorder,
      extensions: const [AppTokens.light],
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppPalette.categorical[0],
      brightness: Brightness.dark,
      surface: AppPalette.darkBackground,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppPalette.darkBackground,
      textTheme: Typography.material2021().white.apply(fontFamily: 'Roboto'),
      cardTheme: CardThemeData(
        color: AppPalette.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppPalette.darkBorder),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppPalette.darkBackground,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppPalette.darkBorder),
        ),
      ),
      dividerColor: AppPalette.darkBorder,
      extensions: const [AppTokens.dark],
    );
  }
}
