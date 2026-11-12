import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _themePrefKey = 'themeMode';

/// Which theme the app shows: follow the system (the default), or force light
/// or dark — chosen in Ajustes (see settings_page.dart). Same shape as
/// `localeProvider`: starts at [ThemeMode.system]; `main()` seeds it with the
/// saved choice ([loadSavedThemeMode]) and Ajustes writes it back through
/// [setThemePreference].
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

/// The theme the user picked last time, or [ThemeMode.system] when they never
/// picked one, the stored value is unknown, or storage isn't available.
Future<ThemeMode> loadSavedThemeMode() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return switch (prefs.getString(_themePrefKey)) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  } catch (_) {
    return ThemeMode.system;
  }
}

/// Applies [mode] now and remembers it for the next app start. A storage
/// failure only costs the persistence, never the switch itself.
Future<void> setThemePreference(WidgetRef ref, ThemeMode mode) async {
  ref.read(themeModeProvider.notifier).state = mode;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (mode == ThemeMode.system) {
      await prefs.remove(_themePrefKey);
    } else {
      await prefs.setString(_themePrefKey, mode == ThemeMode.dark ? 'dark' : 'light');
    }
  } catch (_) {}
}
