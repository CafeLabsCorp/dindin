// The Dashboard's onboarding tutorial: when it starts, what it lights up and
// how it is recorded (docs/onboarding-design.md §2.3 and §3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/tutorial_progress.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_shell.dart' show AppNavigation;

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(TutorialPage.dashboard);
    registerFallbackValue(TutorialState.done);
  });

  late _MockFirestoreService firestore;
  late ProviderContainer container;
  var menuOpened = 0;
  final railKey = GlobalKey();

  Future<void> pumpDashboard(
    WidgetTester tester, {
    Stream<Map<TutorialPage, TutorialEntry>>? progress,
    bool wide = false,
    Size size = const Size(400, 800),
  }) async {
    menuOpened = 0;
    firestore = _MockFirestoreService();
    when(() => firestore.setTutorialProgress(any(), any())).thenAnswer((_) async {});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cats = [const Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01')];
    final allocs = [const Allocation(id: 'a1', categoryId: 'c1', amount: 100, date: '2026-01-02')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          tutorialProgressProvider.overrideWith((ref) => progress ?? Stream.value(<TutorialPage, TutorialEntry>{})),
          recurringChargesCatchUpProvider.overrideWith((ref) async => const RecurringChargeReport()),
          categoriesProvider.overrideWith((ref) => Stream.value(cats)),
          allocationsProvider.overrideWith((ref) => Stream.value(allocs)),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(allocs)),
          allIncomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) {
                container = ProviderScope.containerOf(context);
                return Row(
                  children: [
                    if (wide) SizedBox(key: railKey, width: 80),
                    Expanded(
                      child: AppNavigation(
                        openMenu: wide ? null : () => menuOpened++,
                        railKey: wide ? railKey : null,
                        child: const DashboardPage(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Lets the host's settle pause (400 ms) and the route animation run.
  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100)); // dados chegam, a pausa de 400 ms começa
    await tester.pump(const Duration(milliseconds: 500)); // a pausa termina e o tutorial abre
    await tester.pumpAndSettle();
  }

  testWidgets('primeira vez: depois dos dados carregarem, o tutorial abre no passo 1 (celular)', (tester) async {
    await pumpDashboard(tester);
    expect(find.text('Aqui você troca de tela'), findsNothing, reason: 'espera a tela assentar');

    await settle(tester);

    expect(find.text('Aqui você troca de tela'), findsOneWidget);
    expect(find.text('1 de 4'), findsOneWidget);
    expect(find.textContaining('Toque no nome da página'), findsOneWidget);
  });

  testWidgets('passa pelos 4 passos e conclui como feito, gravando no perfil', (tester) async {
    await pumpDashboard(tester);
    await settle(tester);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('O dinheiro entra na conta'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Depois, distribua'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('Suas caixinhas'), findsOneWidget);
    expect(find.text('4 de 4'), findsOneWidget);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();

    verify(() => firestore.setTutorialProgress(TutorialPage.dashboard, TutorialState.done)).called(1);
    expect(container.read(tutorialSeenProvider(TutorialPage.dashboard)), isTrue);
    expect(find.text('Suas caixinhas'), findsNothing, reason: 'não reabre');
  });

  testWidgets('Pular grava como pulado e não volta a aparecer', (tester) async {
    await pumpDashboard(tester);
    await settle(tester);

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    await settle(tester);

    verify(() => firestore.setTutorialProgress(TutorialPage.dashboard, TutorialState.skipped)).called(1);
    expect(find.text('Aqui você troca de tela'), findsNothing);
  });

  testWidgets('no passo do menu, tocar no título abre o menu de verdade e conta como visto', (tester) async {
    await pumpDashboard(tester);
    await settle(tester);

    await tester.tap(find.text('Dashboard'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(menuOpened, 1);
    verify(() => firestore.setTutorialProgress(TutorialPage.dashboard, TutorialState.done)).called(1);
    expect(find.text('Aqui você troca de tela'), findsNothing);
  });

  testWidgets('quem já viu o tutorial (na versão atual) não o vê de novo', (tester) async {
    await pumpDashboard(
      tester,
      progress: Stream.value({
        TutorialPage.dashboard: const TutorialEntry(state: TutorialState.done, version: 1),
      }),
    );
    await settle(tester);

    expect(find.text('Aqui você troca de tela'), findsNothing);
    verifyNever(() => firestore.setTutorialProgress(any(), any()));
  });

  testWidgets('enquanto o progresso salvo não chegou, nada aparece (sem piscar)', (tester) async {
    await pumpDashboard(tester, progress: const Stream.empty());
    await settle(tester);

    expect(find.text('Aqui você troca de tela'), findsNothing);
  });

  testWidgets('um diálogo aberto por cima segura o tutorial até fechar', (tester) async {
    await pumpDashboard(tester);
    final context = tester.element(find.byType(DashboardPage));
    showDialog<void>(context: context, builder: (_) => const AlertDialog(title: Text('Lembrete'), content: Text('x')));
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();
    expect(find.text('Aqui você troca de tela'), findsNothing, reason: 'o diálogo está na frente');

    Navigator.of(tester.element(find.text('Lembrete'))).pop();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Aqui você troca de tela'), findsOneWidget);
  });

  testWidgets('tela larga: o passo 1 destaca a barra lateral, com o texto da barra', (tester) async {
    await pumpDashboard(tester, wide: true, size: const Size(1000, 800));
    await settle(tester);

    expect(find.text('Aqui você troca de tela'), findsOneWidget);
    expect(find.text('As telas do app ficam nesta barra.'), findsOneWidget);
    expect(find.textContaining('Toque no nome da página'), findsNothing);
  });

  testWidgets('"Rever" em Ajustes (zera a página) faz o tutorial voltar', (tester) async {
    await pumpDashboard(tester);
    await settle(tester);
    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();
    expect(container.read(tutorialSeenProvider(TutorialPage.dashboard)), isTrue);

    // O mesmo que "Rever" faz: esquece a marca da sessão.
    container.read(tutorialSessionSeenProvider.notifier).state = const {};
    await tester.pump();
    await settle(tester);

    expect(find.text('Aqui você troca de tela'), findsOneWidget);
  });
}
