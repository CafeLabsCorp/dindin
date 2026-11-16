// "Lançar receita" / "Lançar gasto" do Dashboard: o formulário abre num popup,
// salva e fecha sem sair da página.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/quick_entry_sheet.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    registerFallbackValue(IncomeSource.estagio);
  });

  late _MockFirestoreService firestore;

  Future<void> pumpHost(WidgetTester tester, {required bool income}) async {
    firestore = _MockFirestoreService();
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          firestoreServiceProvider.overrideWithValue(firestore),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          expensesProvider.overrideWith((ref) => Stream.value([_expense])),
          allIncomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showQuickEntrySheet(context, income: income),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  testWidgets('receita: salva, mostra a confirmação e fecha o popup', (tester) async {
    await pumpHost(tester, income: true);
    when(
      () => firestore.createIncome(
        date: any(named: 'date'),
        amount: any(named: 'amount'),
        source: any(named: 'source'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => const Income(id: 'i1', date: '2026-01-01', amount: 10, source: IncomeSource.estagio));

    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '10,00');
    await tester.tap(find.widgetWithText(FilledButton, 'Lançar receita').last);
    await tester.pumpAndSettle();

    verify(
      () => firestore.createIncome(
        date: any(named: 'date'),
        amount: 10,
        source: any(named: 'source'),
        description: null,
      ),
    ).called(1);
    expect(find.byType(BottomSheet), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);
  });

  testWidgets('valor vazio: mostra o erro e não grava nem fecha', (tester) async {
    await pumpHost(tester, income: true);

    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    verifyNever(
      () => firestore.createIncome(
        date: any(named: 'date'),
        amount: any(named: 'amount'),
        source: any(named: 'source'),
        description: any(named: 'description'),
      ),
    );
    expect(find.byType(BottomSheet), findsOneWidget);
  });

  testWidgets('gasto: salva pela Conta e fecha o popup', (tester) async {
    await pumpHost(tester, income: false);
    when(
      () => firestore.createExpense(
        date: any(named: 'date'),
        amount: any(named: 'amount'),
        categoryId: any(named: 'categoryId'),
        description: any(named: 'description'),
      ),
    ).thenAnswer((_) async => _expense);

    await tester.enterText(find.widgetWithText(TextField, 'Valor'), '25,50');
    await tester.tap(find.byType(FilledButton).last);
    await tester.pumpAndSettle();

    verify(
      () => firestore.createExpense(
        date: any(named: 'date'),
        amount: 25.5,
        categoryId: null,
        description: null,
      ),
    ).called(1);
    expect(find.byType(BottomSheet), findsNothing);
  });
}

const _expense = Expense(id: 'e0', date: '2026-01-01', amount: 1, createdAt: '2026-01-01');
