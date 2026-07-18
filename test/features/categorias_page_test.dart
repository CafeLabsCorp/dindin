import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/categorias/categorias_page.dart';
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

  const casaComLimite = Category(
    id: 'c1',
    name: 'Casa',
    recurring: true,
    createdAt: '2026-01-01',
    monthlyBudget: 100,
  );
  final gastoDoMes = Expense(id: 'e1', date: DateTime.now().toIso8601String().substring(0, 10), amount: 30, categoryId: 'c1');

  Future<void> pump(
    WidgetTester tester, {
    required List<Category> categories,
    List<Expense> expenses = const [],
    List<Allocation> allocations = const [],
  }) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          expensesProvider.overrideWith((ref) => Stream.value(expenses)),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(allocations)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: CategoriasPage()),
        ),
      ),
    );
  }

  testWidgets('formulário de criação abre no modo Guardar (meta) e alterna pra Gastar (limite)', (tester) async {
    await pump(tester, categories: []);
    await tester.pumpAndSettle();

    // Default purpose is "Guardar" → goal field visible, no monthly limit.
    expect(find.text('Meta de valor (opcional)'), findsOneWidget);
    expect(find.text('Limite mensal de gasto (opcional)'), findsNothing);

    await tester.tap(find.text('Gastar').first);
    await tester.pumpAndSettle();

    expect(find.text('Limite mensal de gasto (opcional)'), findsOneWidget);
    expect(find.text('Meta de valor (opcional)'), findsNothing);
  });

  testWidgets('categoria com limite mostra a CaixinhaBudgetBar com o gasto do mês', (tester) async {
    await pump(tester, categories: [casaComLimite], expenses: [gastoDoMes]);
    await tester.pumpAndSettle();

    expect(find.text('Gasto: ${formatCurrency(30)} de ${formatCurrency(100)} este mês'), findsOneWidget);
  });

  testWidgets('caixinha de guardar com meta mostra a CaixinhaGoalBar com o saldo acumulado', (tester) async {
    const cofrinho = Category(
      id: 'c2',
      name: 'Viagem',
      recurring: true,
      createdAt: '2026-01-01',
      kind: CategoryKind.save,
      goalAmount: 1000,
    );
    await pump(tester, categories: [cofrinho]);
    await tester.pumpAndSettle();

    // No allocations in the overrides → saved = 0 of 1000.
    expect(find.text('${formatCurrency(0)} de ${formatCurrency(1000)} guardados (0%)'), findsOneWidget);
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

  // -- catDebtFree guard (UI): the delete icon and the "Guardar" segment are
  // proactively disabled while a spend caixinha is indebted (mirrors
  // FirestoreService's catDebtFree guard) — see `_hasUnsettledDebt` in
  // categorias_page.dart.

  const caixinhaEndividada = Category(
    id: 'c1',
    name: 'Lazer',
    recurring: false,
    createdAt: '2026-01-01',
    kind: CategoryKind.spend,
  );

  testWidgets('ícone de remover fica desabilitado quando a caixinha (spend) está com saldo negativo', (tester) async {
    // allocation 30 - expense 50 = -20 -> summaryProvider.balancesByCategory['c1'] < 0.
    await pump(
      tester,
      categories: [caixinhaEndividada],
      allocations: [const Allocation(id: 'a1', categoryId: 'c1', amount: 30, date: '2026-01-02')],
      expenses: [const Expense(id: 'e1', date: '2026-01-03', amount: 50, categoryId: 'c1')],
    );
    await tester.pumpAndSettle();

    // find.byTooltip locates the Tooltip widget itself (a DESCENDANT of the
    // IconButton, not the button); walk back up to the actual IconButton.
    final deleteButton = tester.widget<IconButton>(
      find.ancestor(
        of: find.byTooltip('Quite a dívida dessa caixinha (saldo de volta a zero) antes de removê-la'),
        matching: find.byType(IconButton),
      ),
    );
    expect(deleteButton.onPressed, isNull);
    expect(find.byTooltip('Remover categoria'), findsNothing);
  });

  testWidgets('ícone de remover fica habilitado quando a caixinha (spend) está com saldo positivo', (tester) async {
    await pump(
      tester,
      categories: [caixinhaEndividada],
      allocations: [const Allocation(id: 'a1', categoryId: 'c1', amount: 50, date: '2026-01-02')],
      expenses: [const Expense(id: 'e1', date: '2026-01-03', amount: 30, categoryId: 'c1')],
    );
    await tester.pumpAndSettle();

    final deleteButton = tester.widget<IconButton>(
      find.ancestor(of: find.byTooltip('Remover categoria'), matching: find.byType(IconButton)),
    );
    expect(deleteButton.onPressed, isNotNull);
  });

  testWidgets('formulário de edição desabilita o segmento "Guardar" quando a caixinha está endividada', (tester) async {
    // Runs at the default 800x600 test surface (matching the "wide" >= 720px
    // breakpoint that picks the Dialog path in showAdaptiveFormSheet). This
    // used to overflow the Dialog's Column by ~47px once the debt-warning
    // Text below the SegmentedButton was added, because the Dialog path
    // (lib/widgets/adaptive_form_sheet.dart) had no SingleChildScrollView
    // wrapper, unlike the narrow/bottom-sheet path. Now that the Dialog path
    // scrolls too, this runs at the real dialog size — no enlarged surface
    // needed — and `tester.takeException()` below asserts no overflow error
    // was thrown.
    await pump(
      tester,
      categories: [caixinhaEndividada],
      allocations: [const Allocation(id: 'a1', categoryId: 'c1', amount: 30, date: '2026-01-02')],
      expenses: [const Expense(id: 'e1', date: '2026-01-03', amount: 50, categoryId: 'c1')],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Lazer'));
    await tester.pumpAndSettle();

    // Asserts no RenderFlex overflow (or any other) exception was thrown
    // while building/laying out the Dialog at its real 800x600 size.
    expect(tester.takeException(), isNull);

    expect(find.text('Editar categoria'), findsOneWidget);
    // The edit form's SegmentedButton is inside the wide-screen Dialog (the
    // default flutter_test surface is 800x600, >= the 720 "wide" breakpoint).
    final segmentedButton = tester.widget<SegmentedButton<CategoryKind>>(
      find.descendant(of: find.byType(Dialog), matching: find.byType(SegmentedButton<CategoryKind>)),
    );
    final guardarSegment = segmentedButton.segments.firstWhere((s) => s.value == CategoryKind.save);
    expect(guardarSegment.enabled, isFalse);
    expect(
      find.text('Quite a dívida dessa caixinha (saldo de volta a zero) antes de convertê-la em cofrinho.'),
      findsOneWidget,
    );
  });

  testWidgets('formulário de edição mantém o segmento "Guardar" habilitado quando a caixinha não está endividada', (tester) async {
    await pump(tester, categories: [casaComLimite]);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Casa'));
    await tester.pumpAndSettle();

    final segmentedButton = tester.widget<SegmentedButton<CategoryKind>>(
      find.descendant(of: find.byType(Dialog), matching: find.byType(SegmentedButton<CategoryKind>)),
    );
    final guardarSegment = segmentedButton.segments.firstWhere((s) => s.value == CategoryKind.save);
    expect(guardarSegment.enabled, isTrue);
  });
}
