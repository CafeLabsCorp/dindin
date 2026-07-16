import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
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
}
