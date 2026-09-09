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

  /// The lower AppCards (Privacidade, Legal, Zona de perigo) sit below the
  /// fold in the test viewport's default size. `find.text` finds a widget
  /// anywhere in the tree regardless of visibility, but `tester.tap` sends a
  /// pointer event at that widget's on-screen offset — off-screen, that hits
  /// nothing (or something else) instead of the target. So every test that
  /// TAPS something below the fold must scroll THAT specific finder into
  /// view first — scrolling straight to the bottom of the page would push an
  /// earlier target (e.g. a legal link) back off the TOP of the viewport.
  Future<void> scrollUntilVisible(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(finder, 300);
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

  group('links legais (item 6 da rodada Forge)', () {
    testWidgets('a seção Legal mostra os links de Política de Privacidade e Termos de Uso', (tester) async {
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.text('Legal'));

      expect(find.text('Legal'), findsOneWidget);
      expect(find.text('Política de Privacidade'), findsOneWidget);
      expect(find.text('Termos de Uso'), findsOneWidget);
    });

    testWidgets('tocar num link legal não derruba a tela mesmo sem um url_launcher real registrado', (tester) async {
      // No ambiente de teste não há plugin de URL registrado — launchUrl
      // lançaria MissingPluginException; _openLink captura e mostra um
      // SnackBar em vez de deixar a exceção subir (ver settings_page.dart).
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.widgetWithText(OutlinedButton, 'Política de Privacidade'));

      // `runAsync` escapes the fake-async zone `testWidgets` normally runs
      // in — the (mocked, unregistered) platform channel round trip
      // `launchUrl` makes never resolves under plain `pump()`s, only under
      // REAL event-loop processing (a real `Future.delayed` inside the same
      // `runAsync` block gives it a turn to do so).
      await tester.runAsync(() async {
        await tester.tap(find.widgetWithText(OutlinedButton, 'Política de Privacidade'));
        await Future<void>.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();
      // Not pumpAndSettle: the SnackBar auto-dismisses on a timer, and
      // pumpAndSettle would pump straight through its whole lifetime.
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Não foi possível abrir o link.'), findsOneWidget);
    });
  });

  group('privacidade / opt-out de analytics (item 7 da rodada Forge, decisão 7)', () {
    testWidgets('mostra o toggle de compartilhamento de dados de uso, ligado por padrão', (tester) async {
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.text('Privacidade'));

      expect(find.text('Privacidade'), findsOneWidget);
      expect(find.text('Compartilhar dados de uso anônimos'), findsOneWidget);
      final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
      expect(toggle.value, isTrue); // opt-out defaults to false -> switch ON
    });

    testWidgets('tocar o toggle sem estar logado não derruba a tela (firestore nulo é tratado)', (tester) async {
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.byType(SwitchListTile));

      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();

      // Sem exceção e sem crash — a tela continua íntegra.
      expect(find.text('Privacidade'), findsOneWidget);
    });
  });

  group('exclusão de conta (item 5 da rodada Forge, decisão 3 — opção A)', () {
    testWidgets('mostra a Zona de perigo com o botão Excluir conta', (tester) async {
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.text('Zona de perigo'));

      expect(find.text('Zona de perigo'), findsOneWidget);
      expect(find.text('Excluir conta'), findsOneWidget);
    });

    testWidgets('tocar em "Excluir conta" abre a confirmação com export oferecido e cancelar fecha sem apagar nada', (tester) async {
      await pumpPage(tester, startLocale: const Locale('pt'));
      await scrollUntilVisible(tester, find.text('Excluir conta'));

      await tester.tap(find.text('Excluir conta'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir conta?'), findsOneWidget);
      expect(find.textContaining('não existe período de carência'), findsOneWidget);
      // O export é OFERECIDO (não obrigatório) — aparece como uma ação ao
      // lado de cancelar/excluir, dentro do PRÓPRIO diálogo (o Backup card
      // por trás também tem um botão "Exportar backup", daí o `descendant`
      // pra mirar só no diálogo).
      final dialog = find.byType(AlertDialog);
      expect(find.descendant(of: dialog, matching: find.text('Exportar backup')), findsOneWidget);
      expect(find.text('Excluir definitivamente'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      // O diálogo fecha e a tela de Ajustes continua normal — nada foi
      // acionado.
      expect(find.text('Excluir conta?'), findsNothing);
      expect(find.text('Zona de perigo'), findsOneWidget);
    });
  });
}
