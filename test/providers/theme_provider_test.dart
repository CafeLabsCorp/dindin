// The theme picked in Ajustes has to survive closing the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dindin/providers/theme_provider.dart';

void main() {
  testWidgets('a escolha de tema é salva e restaurada na próxima abertura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadSavedThemeMode(), ThemeMode.system, reason: 'sem escolha, segue o sistema');

    late WidgetRef ref;
    await tester.pumpWidget(
      ProviderScope(
        child: Consumer(
          builder: (context, r, _) {
            ref = r;
            return const SizedBox();
          },
        ),
      ),
    );

    await setThemePreference(ref, ThemeMode.dark);
    expect(ref.read(themeModeProvider), ThemeMode.dark);
    expect(await loadSavedThemeMode(), ThemeMode.dark);

    await setThemePreference(ref, ThemeMode.light);
    expect(await loadSavedThemeMode(), ThemeMode.light);

    await setThemePreference(ref, ThemeMode.system);
    expect(ref.read(themeModeProvider), ThemeMode.system);
    expect(await loadSavedThemeMode(), ThemeMode.system, reason: '"Sistema" apaga a preferência salva');
  });

  testWidgets('um valor guardado desconhecido volta a seguir o sistema', (tester) async {
    SharedPreferences.setMockInitialValues({'themeMode': 'sepia'});
    expect(await loadSavedThemeMode(), ThemeMode.system);
  });
}
