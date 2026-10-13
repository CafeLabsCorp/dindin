// The language picked in Ajustes has to survive closing the app.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:dindin/providers/locale_provider.dart';

void main() {
  testWidgets('a escolha de idioma é salva e restaurada na próxima abertura', (tester) async {
    SharedPreferences.setMockInitialValues({});
    expect(await loadSavedLocale(), isNull, reason: 'sem escolha, segue o sistema');

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

    await setLocalePreference(ref, const Locale('en'));
    expect(ref.read(localeProvider), const Locale('en'));
    expect(await loadSavedLocale(), const Locale('en'));

    await setLocalePreference(ref, null);
    expect(ref.read(localeProvider), isNull);
    expect(await loadSavedLocale(), isNull, reason: '"Sistema" apaga a preferência salva');
  });
}
