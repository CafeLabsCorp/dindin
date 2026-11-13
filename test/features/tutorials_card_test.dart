// Ajustes -> Tutoriais: progress, see one again, see all again with Undo, and
// the Ajustes page's own tutorial (docs/onboarding-design.md §5 and §3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/settings/settings_page.dart';
import 'package:dindin/features/settings/tutorials_card.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/tutorial_progress.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/auth_service.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

class _MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() {
    registerFallbackValue(TutorialPage.dashboard);
    registerFallbackValue(TutorialState.done);
  });

  late _MockFirestoreService firestore;
  late String location;

  const seenAndSkipped = {
    TutorialPage.dashboard: TutorialEntry(state: TutorialState.done, version: 1),
    TutorialPage.gastos: TutorialEntry(state: TutorialState.skipped, version: 1),
  };

  Future<void> pumpCard(
    WidgetTester tester, {
    Stream<Map<TutorialPage, TutorialEntry>>? progress,
    Widget? home,
    Size size = const Size(400, 900),
  }) async {
    firestore = _MockFirestoreService();
    when(() => firestore.setTutorialProgress(any(), any(), version: any(named: 'version'))).thenAnswer((_) async {});
    when(() => firestore.resetTutorial(any())).thenAnswer((_) async {});
    when(() => firestore.resetAllTutorials()).thenAnswer((_) async {});
    when(() => firestore.setTutorialProgress(any(), any())).thenAnswer((_) async {});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    location = '/ajustes';

    final auth = _MockAuthService();
    when(() => auth.reloadCurrentUser()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/ajustes',
      routes: [
        GoRoute(
          path: '/:page(.*)',
          builder: (context, state) {
            location = state.uri.path;
            return Scaffold(
              body: state.uri.path == '/ajustes'
                  ? (home ?? const SingleChildScrollView(child: TutorialsCard()))
                  : Text('página ${state.uri.path}'),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          authServiceProvider.overrideWithValue(auth),
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          tutorialProgressProvider.overrideWith((ref) => progress ?? Stream.value(seenAndSkipped)),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('enquanto o progresso salvo não chegou, o cartão não aparece', (tester) async {
    await pumpCard(tester, progress: const Stream.empty());
    expect(find.text('Tutoriais'), findsNothing);
  });

  testWidgets('mostra "2 de 7 vistos", uma linha por página na ordem do menu e o status de cada uma', (tester) async {
    await pumpCard(tester);

    expect(find.text('Tutoriais'), findsOneWidget);
    expect(find.text('2 de 7 vistos'), findsOneWidget);
    expect(find.text('Visto'), findsOneWidget); // Dashboard
    expect(find.text('Pulado'), findsOneWidget); // Gastos
    expect(find.text('Ainda não'), findsNWidgets(5));
    expect(find.text('Rever'), findsNWidgets(2));
    expect(find.text('Ver'), findsNWidgets(5));
    final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(bar.value, closeTo(2 / 7, 0.001));
  });

  testWidgets('"Rever" esquece a página e abre ela, onde o tutorial começa', (tester) async {
    await pumpCard(tester);

    // Linha do Gastos (pulado): o botão é "Rever".
    final gastosRow = find.ancestor(of: find.text('Pulado'), matching: find.byType(Row)).first;
    await tester.tap(find.descendant(of: gastosRow, matching: find.byType(TextButton)));
    await tester.pumpAndSettle();

    verify(() => firestore.resetTutorial(TutorialPage.gastos)).called(1);
    expect(location, '/gastos');
    expect(find.text('página /gastos'), findsOneWidget);
  });

  testWidgets('"Ver" numa página ainda não vista também abre a página', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Ver').first); // Receitas (a primeira ainda não vista, depois do Dashboard)
    await tester.pumpAndSettle();

    verify(() => firestore.resetTutorial(TutorialPage.receitas)).called(1);
    expect(location, '/receitas');
  });

  testWidgets('"Rever todos" zera sem pedir confirmação e o "Desfazer" devolve o que estava', (tester) async {
    await pumpCard(tester);

    await tester.tap(find.text('Rever todos'));
    await tester.pump();

    expect(find.byType(AlertDialog), findsNothing, reason: 'sem diálogo de confirmação');
    verify(() => firestore.resetAllTutorials()).called(1);
    expect(find.text('Os tutoriais vão aparecer de novo quando você abrir cada página.'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 750)); // o snackbar termina de subir
    await tester.tap(find.text('Desfazer'));
    await tester.pump();

    verify(() => firestore.setTutorialProgress(TutorialPage.dashboard, TutorialState.done, version: 1)).called(1);
    verify(() => firestore.setTutorialProgress(TutorialPage.gastos, TutorialState.skipped, version: 1)).called(1);
  });

  testWidgets('leitor de tela: cada linha é lida com página, status e ação', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpCard(tester);

    expect(find.bySemanticsLabel('Gastos, Pulado, botão Rever'), findsOneWidget);
    expect(find.bySemanticsLabel('Receitas, Ainda não, botão Ver'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('cabe numa tela de 320 px com fonte x1.3, sem estourar', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await pumpCard(tester, size: const Size(320, 900));

    expect(find.text('Parcelamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  group('selo ao completar os 7', () {
    final all = {
      for (final page in TutorialPage.values)
        page: const TutorialEntry(state: TutorialState.done, version: 1),
    };

    testWidgets('com 7 de 7 aparece o selo e a lista recolhe numa linha', (tester) async {
      await pumpCard(tester, progress: Stream.value(all));

      expect(find.text('7 de 7 vistos'), findsOneWidget);
      expect(find.byType(SvgPicture), findsOneWidget, reason: 'o selo');
      expect(find.text('Você já viu todos. Pode rever qualquer um.'), findsOneWidget);
      expect(find.text('Receitas'), findsNothing, reason: 'a lista está recolhida');
      expect(find.text('Rever todos'), findsOneWidget);
    });

    testWidgets('"Mostrar" abre a lista e "Ocultar" recolhe de novo', (tester) async {
      await pumpCard(tester, progress: Stream.value(all));

      await tester.tap(find.text('Mostrar'));
      await tester.pumpAndSettle();
      expect(find.text('Receitas'), findsOneWidget);
      expect(find.text('Rever'), findsNWidgets(7));
      expect(find.text('Você já viu todos. Pode rever qualquer um.'), findsNothing);

      await tester.tap(find.text('Ocultar'));
      await tester.pumpAndSettle();
      expect(find.text('Receitas'), findsNothing);
      expect(find.text('Você já viu todos. Pode rever qualquer um.'), findsOneWidget);
    });

    testWidgets('o selo é decorativo pro leitor de tela', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpCard(tester, progress: Stream.value(all));

      expect(find.bySemanticsLabel(RegExp('selo', caseSensitive: false)), findsNothing);
      handle.dispose();
    });

    testWidgets('com menos de 7 não há selo nem recolhimento', (tester) async {
      await pumpCard(tester);

      expect(find.byType(SvgPicture), findsNothing);
      expect(find.text('Você já viu todos. Pode rever qualquer um.'), findsNothing);
      expect(find.text('Mostrar'), findsNothing);
      expect(find.text('Receitas'), findsOneWidget);
    });
  });

  group('tutorial da própria página de Ajustes', () {
    testWidgets('2 passos: o cartão de Backup e o cartão de Tutoriais', (tester) async {
      await pumpCard(tester, home: const SettingsPage(), size: const Size(400, 1200));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.text('Guarde uma cópia'), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);

      await tester.tap(find.text('Próximo'));
      await tester.pumpAndSettle();
      expect(find.text('Rever explicações'), findsOneWidget);
      expect(find.text('2 de 2'), findsOneWidget);
    });
  });
}
