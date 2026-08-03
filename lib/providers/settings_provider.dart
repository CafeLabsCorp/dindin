/// The two look-and-feel choices from Ajustes — theme and language — and
/// their persistence.
///
/// They're stored on the DEVICE, not in Firestore, on purpose: they describe
/// how this screen should look, not what the user's money is. Reading them
/// from the ledger would also mean they couldn't apply until after sign-in,
/// which is exactly when the wrong theme is most jarring.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Overridden in `main()` with the already-loaded instance.
///
/// Loading happens BEFORE `runApp` so the very first frame is already in the
/// right theme. An async provider would paint light-then-dark on every cold
/// start, which is the flash this design exists to avoid.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override sharedPreferencesProvider in main()'),
);

const _themeModeKey = 'settings.themeMode';
const _localeKey = 'settings.locale';

/// Light / dark / follow the system. [ThemeMode.system] is the default and is
/// what a fresh install gets.
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>(
  (ref) => ThemeModeNotifier(ref.watch(sharedPreferencesProvider)),
);

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SharedPreferences _prefs;

  ThemeModeNotifier(this._prefs) : super(_read(_prefs));

  static ThemeMode _read(SharedPreferences prefs) {
    return switch (prefs.getString(_themeModeKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      // Covers both "never chose" and a value written by some future build
      // that this one doesn't know: following the system is always a sane
      // thing to do, so an unreadable preference degrades quietly.
      _ => ThemeMode.system,
    };
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await _prefs.setString(_themeModeKey, mode.name);
  }
}

/// `null` means "follow the system locale". PT is what `AppLocalizations`
/// falls back to when the resolved locale isn't supported (see l10n.yaml's
/// `preferred-supported-locales`), matching this product's Portuguese-first
/// copy.
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale?>(
  (ref) => LocaleNotifier(ref.watch(sharedPreferencesProvider)),
);

class LocaleNotifier extends StateNotifier<Locale?> {
  final SharedPreferences _prefs;

  LocaleNotifier(this._prefs) : super(_read(_prefs));

  static Locale? _read(SharedPreferences prefs) {
    final code = prefs.getString(_localeKey);
    // Only the languages this build actually ships. Anything else — an
    // unsupported code, or one a newer build wrote — reads as "follow the
    // system" rather than forcing a locale with no translations behind it.
    return switch (code) {
      'pt' => const Locale('pt'),
      'en' => const Locale('en'),
      _ => null,
    };
  }

  Future<void> set(Locale? locale) async {
    state = locale;
    if (locale == null) {
      await _prefs.remove(_localeKey);
    } else {
      await _prefs.setString(_localeKey, locale.languageCode);
    }
  }
}
