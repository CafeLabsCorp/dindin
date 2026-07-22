import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/features/settings/settings_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/providers/locale_provider.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  // localeProvider is seeded to a known value (not left at its real default
  // of null/"follow system") — the widget-test binding resolves "system" to
  // whatever locale the machine running the tests is set to, which isn't pt
  // on every machine/CI runner. Same reasoning as the fix applied to the
  // other widget tests after the i18n rollout.
  Future<void> pumpPage(WidgetTester tester, {required Locale startLocale}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Signed-out: settings_page.dart only ever `.value`s this to render
          // an email/display name (falls back to '—'), so a null user keeps
          // this test independent of any real Firebase/auth setup.
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          localeProvider.overrideWith((ref) => startLocale),
        ],
        // Reads localeProvider the same way DindinApp's real
        // MaterialApp.router does — this is what makes "tap English -> UI
        // actually switches" an end-to-end check of the Ajustes selector,
        // not just a check that the provider's state changed in isolation.
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            locale: ref.watch(localeProvider),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: AppTheme.light(),
            home: const Scaffold(body: SettingsPage()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renderiza a seção de idioma e o rótulo "Sair" em pt quando o locale é pt', (tester) async {
    await pumpPage(tester, startLocale: const Locale('pt'));

    expect(find.text('Idioma'), findsOneWidget);
    expect(find.text('Sair'), findsOneWidget);
  });

  testWidgets('tocar em "English" troca o locale do app e a UI re-renderiza em inglês', (tester) async {
    await pumpPage(tester, startLocale: const Locale('pt'));

    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out'), findsOneWidget);
    expect(find.text('Sair'), findsNothing);
    expect(find.text('Language'), findsOneWidget);
  });

  testWidgets('tocar em "Português" depois de já estar em inglês volta pro pt', (tester) async {
    await pumpPage(tester, startLocale: const Locale('en'));

    expect(find.text('Sign out'), findsOneWidget);

    await tester.tap(find.text('Português'));
    await tester.pumpAndSettle();

    expect(find.text('Sair'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
  });
}
