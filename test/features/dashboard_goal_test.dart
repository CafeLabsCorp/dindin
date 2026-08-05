// Regression coverage for the Dashboard's own goal-bar rendering — it builds
// the caixinha rows independently of Categorias (a separate local record,
// see dashboard_page.dart), so a bug in one doesn't guarantee the other is
// fine. See categorias_page_test.dart for the same coupling tested there.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
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
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: DashboardPage()),
        ),
      ),
    );
  }

  testWidgets('meta recorrente no Dashboard usa o guardado do mês, não o saldo total', (tester) async {
    const casamento = Category(
      id: 'c1',
      name: 'Casamento',
      recurring: true,
      createdAt: '2025-01-01',
      kind: CategoryKind.save,
      goalAmount: 800,
    );
    final hoje = DateTime.now().toIso8601String().substring(0, 10);
    await pump(
      tester,
      categories: [casamento],
      allocations: [
        const Allocation(id: 'antiga', categoryId: 'c1', amount: 500, date: '2025-06-01'),
        Allocation(id: 'atual', categoryId: 'c1', amount: 300, date: hoje),
      ],
    );
    await tester.pumpAndSettle();

    // 300 deste mês de 800, não os 800 (500+300) de saldo total acumulado.
    expect(
      find.text('${formatCurrency(300)} de ${formatCurrency(800)} guardados este mês (38%)'),
      findsOneWidget,
    );
    // O saldo total (500+300=800) aparece duas vezes: sem rótulo, no valor
    // grande de sempre no topo da linha, E de novo com o rótulo explícito
    // "Saldo total" logo abaixo da barra — a barra sozinha mostra 300 (só
    // este mês), então sem essa legenda o total nunca apareceria rotulado.
    expect(find.text(formatCurrency(800)), findsOneWidget);
    expect(find.text('Saldo total: ${formatCurrency(800)}'), findsOneWidget);
  });

  testWidgets('meta não-recorrente no Dashboard continua contra o saldo total, como sempre foi', (tester) async {
    const viagem = Category(
      id: 'c1',
      name: 'Viagem',
      recurring: false,
      createdAt: '2025-01-01',
      kind: CategoryKind.save,
      goalAmount: 1000,
    );
    await pump(
      tester,
      categories: [viagem],
      allocations: [const Allocation(id: 'a1', categoryId: 'c1', amount: 400, date: '2025-06-01')],
    );
    await tester.pumpAndSettle();

    // Dashboard has legitimate unrelated "este mês" text elsewhere (the
    // Recebido/Gasto/Saldo do mês stat tiles), so the meaningful check is
    // this EXACT caption — the non-monthly variant, with no "este mês" in
    // it — rather than a page-wide absence check.
    expect(find.text('${formatCurrency(400)} de ${formatCurrency(1000)} guardados (40%)'), findsOneWidget);
  });
}
