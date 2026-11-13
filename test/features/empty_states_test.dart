// Guided empty states (docs/onboarding-design.md §4): each page says what to
// do next and its button takes the user to the right field; the Dashboard has
// the "Primeiros passos" card.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/assinaturas/assinaturas_page.dart';
import 'package:dindin/features/categorias/categorias_page.dart';
import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/features/parcelamentos/parcelamentos_page.dart';
import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_shell.dart' show AppNavigation;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  late String location;

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page, {
    List<Category> categories = const [],
    List<Income> incomes = const [],
    List<Allocation> allocations = const [],
    Size size = const Size(400, 900),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    location = '/';
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/:page(.*)',
          builder: (context, state) {
            location = state.uri.path;
            return Scaffold(
              body: state.uri.path.isEmpty || state.uri.path == '/'
                  ? Padding(padding: const EdgeInsets.all(16), child: AppNavigation(openMenu: () {}, child: page))
                  : Text('página ${state.uri.path}'),
            );
          },
        ),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringChargesCatchUpProvider.overrideWith((ref) async => const RecurringChargeReport()),
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          incomesProvider.overrideWith((ref) => Stream.value(incomes)),
          allocationsProvider.overrideWith((ref) => Stream.value(allocations)),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          allIncomesProvider.overrideWith((ref) => Stream.value(incomes)),
          allAllocationsProvider.overrideWith((ref) => Stream.value(allocations)),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          subscriptionsProvider.overrideWith((ref) => Stream.value(<Subscription>[])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(<InstallmentPurchase>[])),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The labelText of the text field that has the cursor, or null.
  String? focusedFieldLabel(WidgetTester tester) {
    final focused = tester.widgetList<TextField>(find.byType(TextField)).where((f) => f.focusNode?.hasFocus ?? false);
    return focused.isEmpty ? null : focused.first.decoration?.labelText;
  }

  final pages = <({String name, Widget Function() build, String title, String action, String field})>[
    (name: 'Receitas', build: () => const ReceitasPage(), title: 'Nenhuma receita ainda', action: 'Adicionar receita', field: 'Valor'),
    (name: 'Gastos', build: () => const GastosPage(), title: 'Nenhum gasto ainda', action: 'Adicionar gasto', field: 'Valor'),
    (name: 'Assinaturas', build: () => const AssinaturasPage(), title: 'Nenhuma assinatura ainda', action: 'Cadastrar assinatura', field: 'Nome'),
    (name: 'Parcelamentos', build: () => const ParcelamentosPage(), title: 'Nenhum parcelamento ainda', action: 'Cadastrar parcelamento', field: 'Nome'),
    (name: 'Categorias', build: () => const CategoriasPage(), title: 'Nenhuma caixinha ainda', action: 'Criar caixinha', field: 'Nome da categoria'),
  ];

  for (final p in pages) {
    testWidgets('${p.name}: estado vazio com título, ação e o botão leva o cursor pro campo certo', (tester) async {
      await pumpPage(tester, p.build());

      expect(find.text(p.title), findsOneWidget);
      expect(find.widgetWithText(FilledButton, p.action), findsOneWidget);
      expect(focusedFieldLabel(tester), isNull, reason: 'nada focado antes do toque');

      await tester.ensureVisible(find.widgetWithText(FilledButton, p.action));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, p.action));
      await tester.pumpAndSettle();

      expect(focusedFieldLabel(tester), p.field);
    });
  }

  testWidgets('Receitas com alguma receita lançada não mostra o vazio de primeira vez', (tester) async {
    await pumpPage(
      tester,
      const ReceitasPage(),
      incomes: [const Income(id: 'i1', date: '2020-01-01', amount: 10, source: IncomeSource.freela)],
    );

    expect(find.text('Nenhuma receita ainda'), findsNothing, reason: 'há receita: não é o vazio de primeira vez');
  });

  group('Dashboard: Primeiros passos', () {
    const cat = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
    final income = const Income(id: 'i1', date: '2026-01-02', amount: 500, source: IncomeSource.freela);
    const alloc = Allocation(id: 'a1', categoryId: 'c1', amount: 200, date: '2026-01-03');

    testWidgets('conta nova: os três passos pendentes, cada um com seu botão', (tester) async {
      await pumpPage(tester, const DashboardPage());

      expect(find.text('Primeiros passos'), findsOneWidget);
      expect(find.text('Crie uma caixinha'), findsOneWidget);
      expect(find.text('Lance uma receita'), findsOneWidget);
      expect(find.text('Aloque na caixinha'), findsOneWidget);
      expect(find.text('Feito'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Criar'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Lançar'), findsOneWidget);
      // Sem caixinha nem saldo, Alocar não faz sentido ainda.
      final allocate = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Alocar'));
      expect(allocate.onPressed, isNull);
    });

    testWidgets('"Criar" abre Categorias e "Lançar" abre Receitas', (tester) async {
      await pumpPage(tester, const DashboardPage());
      await tester.tap(find.widgetWithText(TextButton, 'Criar'));
      await tester.pumpAndSettle();
      expect(location, '/categorias');

      await pumpPage(tester, const DashboardPage());
      await tester.tap(find.widgetWithText(TextButton, 'Lançar'));
      await tester.pumpAndSettle();
      expect(location, '/receitas');
    });

    testWidgets('passo feito vira "Feito" riscado; com a caixinha criada só falta receita e alocar', (tester) async {
      await pumpPage(tester, const DashboardPage(), categories: [cat]);

      expect(find.text('Feito'), findsOneWidget);
      final done = tester.widget<Text>(find.text('Crie uma caixinha'));
      expect(done.style?.decoration, TextDecoration.lineThrough);
      expect(find.widgetWithText(TextButton, 'Criar'), findsNothing);
    });

    testWidgets('com caixinha e receita, "Alocar" fica habilitado', (tester) async {
      await pumpPage(tester, const DashboardPage(), categories: [cat], incomes: [income]);

      final allocate = tester.widget<TextButton>(find.widgetWithText(TextButton, 'Alocar'));
      expect(allocate.onPressed, isNotNull);
    });

    testWidgets('os três feitos: o cartão some', (tester) async {
      await pumpPage(tester, const DashboardPage(), categories: [cat], incomes: [income], allocations: [alloc]);

      expect(find.text('Primeiros passos'), findsNothing);
    });

    testWidgets('histórico vazio tem o botão "Lançar receita" que abre Receitas', (tester) async {
      await pumpPage(tester, const DashboardPage()); // conta nova: sem receita, o histórico está vazio
      await tester.ensureVisible(find.text('Lançar receita'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lançar receita'));
      await tester.pumpAndSettle();

      expect(location, '/receitas');
    });
  });
}
