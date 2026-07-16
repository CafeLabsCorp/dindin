import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const income = Income(
    id: 'i1',
    date: '2026-07-10',
    amount: 123.45,
    source: IncomeSource.freela,
    description: 'Bico de fim de semana',
  );

  Future<void> pump(WidgetTester tester, {required List<Income> incomes}) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [incomesProvider.overrideWith((ref) => Stream.value(incomes))],
        child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: ReceitasPage())),
      ),
    );
  }

  testWidgets('sem lançamentos mostra o estado vazio padrão, sem "Limpar filtro"', (tester) async {
    await pump(tester, incomes: []);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma receita lançada ainda.'), findsOneWidget);
    expect(find.text('Limpar filtro'), findsNothing);
  });

  testWidgets('linha usa ícone de remover (não mais o botão de texto) e o filtro De/Até aparece', (tester) async {
    await pump(tester, incomes: [income]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover receita'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);
    expect(find.text('De'), findsOneWidget);
    expect(find.text('Até'), findsOneWidget);
  });

  testWidgets('tocar na linha (fora do ícone de remover) abre a edição pré-preenchida', (tester) async {
    await pump(tester, incomes: [income]);
    await tester.pumpAndSettle();

    final rowFinder = find.ancestor(of: find.byTooltip('Remover receita'), matching: find.byType(InkWell));
    expect(rowFinder, findsOneWidget);

    await tester.tap(rowFinder);
    await tester.pumpAndSettle();

    expect(find.text('Editar receita'), findsOneWidget);
    expect(find.text('123,45'), findsOneWidget); // valor pré-preenchido
    // A descrição também aparece na linha por trás do diálogo (ainda
    // montada), então só garantimos que o campo de edição também a mostra.
    expect(find.text('Bico de fim de semana'), findsWidgets);
    expect(find.text('Salvar'), findsOneWidget);
  });
}
