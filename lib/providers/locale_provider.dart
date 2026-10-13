import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _localePrefKey = 'locale';

/// null means "follow the system locale" — overridable from Ajustes (see
/// settings_page.dart). PT is what `AppLocalizations` falls back to when the
/// resolved locale isn't supported (see l10n.yaml's
/// `preferred-supported-locales`), matching this product's Portuguese-first
/// copy.
///
/// Starts at null; `main()` seeds it with the saved choice (see
/// [loadSavedLocale]) and Ajustes writes it back through [setLocalePreference].
final localeProvider = StateProvider<Locale?>((ref) => null);

/// The language the user picked last time, or null (follow the system) when
/// they never picked one or storage isn't available.
Future<Locale?> loadSavedLocale() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_localePrefKey);
    return code == null ? null : Locale(code);
  } catch (_) {
    return null;
  }
}

/// Applies [locale] now and remembers it for the next app start. A storage
/// failure only costs the persistence, never the switch itself.
Future<void> setLocalePreference(WidgetRef ref, Locale? locale) async {
  ref.read(localeProvider.notifier).state = locale;
  try {
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_localePrefKey);
    } else {
      await prefs.setString(_localePrefKey, locale.languageCode);
    }
  } catch (_) {}
}
