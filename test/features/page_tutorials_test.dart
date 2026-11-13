// The onboarding tutorials of Receitas, Gastos, Assinaturas, Parcelamentos and
// Categorias: each opens on its first visit, every step finds its element on
// screen (no "unavailable"), and finishing records the page as done
// (docs/onboarding-design.md §3).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/assinaturas/assinaturas_page.dart';
import 'package:dindin/features/categorias/categorias_page.dart';
import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/features/parcelamentos/parcelamentos_page.dart';
import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
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

  final pages = <({TutorialPage page, Widget Function() build, List<String> titles})>[
    (
      page: TutorialPage.receitas,
      build: () => const ReceitasPage(),
      titles: ['Lance o que entrou', 'É só lançar', 'Tudo o que entrou fica aqui'],
    ),
    (
      page: TutorialPage.gastos,
      build: () => const GastosPage(),
      titles: ['Lance um gasto', 'Escolha de onde sai', 'Seus gastos ficam aqui'],
    ),
    (
      page: TutorialPage.assinaturas,
      build: () => const AssinaturasPage(),
      titles: ['Cadastre uma vez', 'Lançado no dia certo', 'Suas assinaturas'],
    ),
    (
      page: TutorialPage.parcelamentos,
      build: () => const ParcelamentosPage(),
      titles: ['Uma compra, várias parcelas', 'Cada parcela sai daqui', 'Adiantar ou quitar'],
    ),
    (
      page: TutorialPage.categorias,
      build: () => const CategoriasPage(),
      titles: ['Cada categoria vira uma caixinha', 'Guardar ou gastar', 'Suas caixinhas'],
    ),
  ];

  late _MockFirestoreService firestore;

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    Size size = const Size(400, 800),
    Map<TutorialPage, TutorialEntry> progress = const {},
  }) async {
    firestore = _MockFirestoreService();
    when(() => firestore.setTutorialProgress(any(), any())).thenAnswer((_) async {});
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final cats = [const Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01')];
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          tutorialProgressProvider.overrideWith((ref) => Stream.value(progress)),
          recurringChargesCatchUpProvider.overrideWith((ref) async => const RecurringChargeReport()),
          categoriesProvider.overrideWith((ref) => Stream.value(cats)),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          allIncomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          subscriptionsProvider.overrideWith((ref) => Stream.value(<Subscription>[])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(<InstallmentPurchase>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: AppNavigation(openMenu: () {}, child: page),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
  }

  for (final p in pages) {
    testWidgets('${p.page.id}: abre na primeira visita, os 3 passos acham seus elementos e conclui', (tester) async {
      await pumpPage(tester, p.build());
      await settle(tester);

      for (var i = 0; i < 3; i++) {
        expect(find.text(p.titles[i]), findsOneWidget, reason: 'passo ${i + 1} de ${p.page.id}');
        expect(find.text('${i + 1} de 3'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FilledButton).last); // Próximo / Entendi
        await tester.pumpAndSettle();
      }

      verify(() => firestore.setTutorialProgress(p.page, TutorialState.done)).called(1);
      expect(find.text(p.titles.last), findsNothing);
    });

    testWidgets('${p.page.id}: cabe numa tela de 320 px com fonte x1.3, sem estourar', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 1.3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpPage(tester, p.build(), size: const Size(320, 640));
      await settle(tester);

      for (var i = 0; i < 3; i++) {
        expect(find.text(p.titles[i]), findsOneWidget);
        final balloon = tester.getRect(find.byType(Material).last);
        expect(balloon.left, greaterThanOrEqualTo(0));
        expect(balloon.right, lessThanOrEqualTo(320));
        expect(balloon.bottom, lessThanOrEqualTo(640));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FilledButton).last);
        await tester.pumpAndSettle();
      }
    });

    testWidgets('${p.page.id}: quem já viu não vê de novo', (tester) async {
      await pumpPage(
        tester,
        p.build(),
        progress: {p.page: const TutorialEntry(state: TutorialState.skipped, version: 1)},
      );
      await settle(tester);

      expect(find.text(p.titles.first), findsNothing);
      verifyNever(() => firestore.setTutorialProgress(any(), any()));
    });
  }
}
