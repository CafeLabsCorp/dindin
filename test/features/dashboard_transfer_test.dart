import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/dashboard/dashboard_page.dart';
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

  const casa = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
  const lazer = Category(id: 'c2', name: 'Lazer', recurring: false, createdAt: '2026-01-02');
  const allocCasa = Allocation(id: 'a1', categoryId: 'c1', amount: 500, date: '2026-01-05');

  Future<void> pump(
    WidgetTester tester, {
    required List<Category> categories,
    List<Allocation> allocations = const [],
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          allocationsProvider.overrideWith((ref) => Stream.value(allocations)),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: DashboardPage())),
      ),
    );
  }

  testWidgets('"Transferir" fica desabilitado quando não há caixinha com saldo positivo', (tester) async {
    await pump(tester, categories: [casa, lazer], allocations: const []); // ambas com saldo 0
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Transferir'));
    expect(button.onPressed, isNull);
  });

  testWidgets('"Transferir" fica desabilitado quando só existe uma caixinha (sem destino possível)', (tester) async {
    await pump(tester, categories: [casa], allocations: [allocCasa]); // c1 tem saldo, mas não há para onde transferir
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Transferir'));
    expect(button.onPressed, isNull);
  });

  testWidgets('"Transferir" habilitado abre o diálogo com a origem elegível pré-selecionada', (tester) async {
    await pump(tester, categories: [casa, lazer], allocations: [allocCasa]); // só c1 tem saldo > 0
    await tester.pumpAndSettle();

    final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Transferir'));
    expect(button.onPressed, isNotNull);

    await tester.tap(find.widgetWithText(FilledButton, 'Transferir'));
    await tester.pumpAndSettle();

    expect(find.text('Transferir entre caixinhas'), findsOneWidget);
    // Casa é a única caixinha com saldo > 0, então deve ser a origem
    // pré-selecionada automaticamente.
    expect(find.text('Disponível na origem: ${formatCurrency(500)}'), findsOneWidget);
  });
}
