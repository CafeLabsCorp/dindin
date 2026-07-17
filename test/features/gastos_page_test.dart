import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const casa = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
  const expense = Expense(id: 'e1', date: '2026-07-05', amount: 80, categoryId: 'c1', description: 'Mercado');

  Future<void> pump(WidgetTester tester, {required List<Expense> expenses}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([casa])),
          expensesProvider.overrideWith((ref) => Stream.value(expenses)),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: GastosPage())),
      ),
    );
  }

  /// Pumps with a caixinha whose running balance (allocations - expenses) is
  /// forced negative, to exercise the proactive "frozen debt" form gate
  /// (`_blockedByFrozenDebt` — decision #3: toggle off + already negative
  /// blocks further gastos). This is a client-side UX safeguard on top of
  /// the actual money-integrity boundary enforced in firestore.rules/
  /// FirestoreService — see test/rules/rules.test.mjs and
  /// firestore_service_test.dart for that layer.
  Future<void> pumpWithNegativeBalance(
    WidgetTester tester, {
    required Category category,
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          incomesProvider.overrideWith(
            (ref) => Stream.value(const [
              Income(id: 'i1', date: '2026-01-01', amount: 100, source: IncomeSource.freela),
            ]),
          ),
          allocationsProvider.overrideWith(
            (ref) => Stream.value(const [
              Allocation(id: 'a1', categoryId: 'c1', amount: 10, date: '2026-01-02'),
            ]),
          ),
          expensesProvider.overrideWith(
            (ref) => Stream.value(const [
              Expense(id: 'e1', date: '2026-01-03', amount: 50, categoryId: 'c1'),
            ]),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: GastosPage())),
      ),
    );
  }

  testWidgets('linha usa ícone de remover e tocar nela abre a edição', (tester) async {
    await pump(tester, expenses: [expense]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover gasto'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);

    final rowFinder = find.ancestor(of: find.byTooltip('Remover gasto'), matching: find.byType(InkWell));
    await tester.tap(rowFinder);
    await tester.pumpAndSettle();

    expect(find.text('Editar gasto'), findsOneWidget);
    expect(find.text('80,00'), findsOneWidget);
    // A caixinha do gasto não pode ser trocada na edição (updateExpense rejeita
    // mover entre alvos) — deve aparecer como campo somente leitura, não um
    // dropdown editável.
    expect(find.text('Casa'), findsWidgets);
    expect(find.text('Não é possível mudar a caixinha por aqui — remova e lance de novo.'), findsOneWidget);
  });

  testWidgets('linha de filtro De/Até aparece acima da lista, sem "Limpar filtro" por padrão', (tester) async {
    await pump(tester, expenses: [expense]);
    await tester.pumpAndSettle();

    expect(find.text('De'), findsOneWidget);
    expect(find.text('Até'), findsOneWidget);
    expect(find.text('Limpar filtro'), findsNothing);
  });

  testWidgets('sem nenhum gasto lançado mostra o estado vazio padrão (não o filtrado)', (tester) async {
    await pump(tester, expenses: []);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum gasto lançado ainda.'), findsOneWidget);
  });

  group('bloqueio de dívida congelada (decisão #3: toggle off + já negativo)', () {
    Future<void> selectCasa(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casa').last);
      await tester.pumpAndSettle();
    }

    testWidgets('caixinha negativa com allowNegative OFF: desabilita valor/descrição/botão e mostra o aviso', (tester) async {
      await pumpWithNegativeBalance(tester, category: casa); // allowNegative unset -> off
      await tester.pumpAndSettle();
      await selectCasa(tester);

      expect(
        find.text('Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos, ou ligue "Permitir saldo negativo" na categoria.'),
        findsOneWidget,
      );

      final valorField = tester.widget<TextField>(
        find.ancestor(of: find.text('Valor'), matching: find.byType(TextField)).first,
      );
      expect(valorField.enabled, isFalse);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lançar gasto'));
      expect(button.onPressed, isNull);
    });

    testWidgets('caixinha negativa com allowNegative ON: NÃO bloqueia (dívida pode se aprofundar)', (tester) async {
      const casaComDivida = Category(
        id: 'c1',
        name: 'Casa',
        recurring: true,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      await pumpWithNegativeBalance(tester, category: casaComDivida);
      await tester.pumpAndSettle();
      await selectCasa(tester);

      expect(find.textContaining('não permite saldo negativo'), findsNothing);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lançar gasto'));
      expect(button.onPressed, isNotNull);
    });
  });
}
