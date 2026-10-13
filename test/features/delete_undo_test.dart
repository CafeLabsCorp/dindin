// Removing a gasto or receita is confirmed with a snackbar that offers to undo
// it — recreating the entry — and a failed removal says so instead of failing
// silently.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(IncomeSource.freela);
  });

  const casa = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
  const expense = Expense(id: 'e1', date: '2026-07-05', amount: 80, categoryId: 'c1', description: 'Mercado');
  const income = Income(id: 'i1', date: '2026-07-01', amount: 500, source: IncomeSource.freela, description: 'Job');

  Future<_MockFirestoreService> pump(WidgetTester tester, Widget page) async {
    await tester.binding.setSurfaceSize(const Size(800, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = _MockFirestoreService();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(service),
          categoriesProvider.overrideWith((ref) => Stream.value([casa])),
          expensesProvider.overrideWith((ref) => Stream.value([expense])),
          incomesProvider.overrideWith((ref) => Stream.value([income])),
          allExpensesProvider.overrideWith((ref) => Stream.value([expense])),
          allIncomesProvider.overrideWith((ref) => Stream.value([income])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(const [])),
          subscriptionsProvider.overrideWith((ref) => Stream.value(const [])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(const [])),
          todayProvider.overrideWithValue(DateTime(2026, 7, 10)),
          recurringChargesCatchUpProvider.overrideWith((ref) async => const RecurringChargeReport()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return service;
  }

  Future<void> confirmRemoval(WidgetTester tester, String tooltip) async {
    await tester.tap(find.byTooltip(tooltip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Remover'));
    await tester.pumpAndSettle();
  }

  testWidgets('remover gasto: confirma e "Desfazer" lança o gasto de volta', (tester) async {
    final service = await pump(tester, const GastosPage());
    when(() => service.deleteExpense('e1')).thenAnswer((_) async {});
    when(
      () => service.createExpense(
        date: any(named: 'date'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => expense);

    await confirmRemoval(tester, 'Remover gasto');
    verify(() => service.deleteExpense('e1')).called(1);
    expect(find.text('Gasto removido.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    verify(
      () => service.createExpense(date: '2026-07-05', amount: 80, categoryId: 'c1', description: 'Mercado'),
    ).called(1);
    expect(find.text('Restaurado.'), findsOneWidget);
  });

  testWidgets('remover receita: confirma e "Desfazer" registra a receita de volta', (tester) async {
    final service = await pump(tester, const ReceitasPage());
    when(() => service.deleteIncome('i1')).thenAnswer((_) async {});
    when(
      () => service.createIncome(
        date: any(named: 'date'),
        amount: any(named: 'amount'),
        source: any(named: 'source'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => income);

    await confirmRemoval(tester, 'Remover receita');
    expect(find.text('Receita removida.'), findsOneWidget);

    await tester.tap(find.text('Desfazer'));
    await tester.pumpAndSettle();
    verify(
      () => service.createIncome(date: '2026-07-01', amount: 500, source: IncomeSource.freela, description: 'Job'),
    ).called(1);
  });

  testWidgets('remoção que falha avisa em vez de falhar em silêncio', (tester) async {
    final service = await pump(tester, const GastosPage());
    when(() => service.deleteExpense('e1')).thenAnswer((_) async => throw StateError('boom'));

    await confirmRemoval(tester, 'Remover gasto');
    expect(find.text('Gasto removido.'), findsNothing);
    expect(find.text('Não foi possível salvar. Tente novamente.'), findsOneWidget);
  });
}
