import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/categorias/categorias_page.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/utils/format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const casaComLimite = Category(
    id: 'c1',
    name: 'Casa',
    recurring: true,
    createdAt: '2026-01-01',
    monthlyBudget: 100,
  );
  final gastoDoMes = Expense(id: 'e1', date: DateTime.now().toIso8601String().substring(0, 10), amount: 30, categoryId: 'c1');

  Future<void> pump(WidgetTester tester, {required List<Category> categories, List<Expense> expenses = const []}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          expensesProvider.overrideWith((ref) => Stream.value(expenses)),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: CategoriasPage())),
      ),
    );
  }

  testWidgets('formulário de criação tem o campo "Limite mensal (opcional)" (§5.2)', (tester) async {
    await pump(tester, categories: []);
    await tester.pumpAndSettle();

    expect(find.text('Limite mensal (opcional)'), findsOneWidget);
  });

  testWidgets('categoria com limite mostra a CaixinhaBudgetBar com o gasto do mês', (tester) async {
    await pump(tester, categories: [casaComLimite], expenses: [gastoDoMes]);
    await tester.pumpAndSettle();

    expect(find.text('${formatCurrency(30)} de ${formatCurrency(100)} este mês'), findsOneWidget);
  });

  testWidgets('tocar na linha abre a edição pré-preenchida (nome + limite mensal)', (tester) async {
    await pump(tester, categories: [casaComLimite]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();

    expect(find.text('Editar categoria'), findsOneWidget);
    expect(find.text('100,00'), findsOneWidget); // limite pré-preenchido
    // O rótulo do checkbox também existe no form de criação (por trás do
    // diálogo, ainda montado) — só garantimos que a edição também o mostra.
    expect(find.text('Recorrente (repete todo mês)'), findsWidgets);
  });

  testWidgets('ícone de remover substitui o antigo botão de texto "Remover"', (tester) async {
    await pump(tester, categories: [casaComLimite]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover categoria'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);
  });
}
