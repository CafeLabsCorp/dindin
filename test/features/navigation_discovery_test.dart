// Making navigation easier to find (docs/onboarding-design.md §6): quick
// buttons on the Dashboard that open Receitas/Gastos with the cursor in the
// amount, the chevron chip on the title, and a line per screen in the menu.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/providers/focus_request.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_shell.dart' show AppNavigation;
import 'package:dindin/widgets/menu_chevron.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    Widget page(Widget child) => Scaffold(
      body: Padding(padding: const EdgeInsets.all(16), child: AppNavigation(openMenu: () {}, child: child)),
    );
    final router = GoRouter(
      routes: [
        GoRoute(path: '/', builder: (_, _) => page(const DashboardPage())),
        GoRoute(path: '/receitas', builder: (_, _) => page(const ReceitasPage())),
        GoRoute(path: '/gastos', builder: (_, _) => page(const GastosPage())),
        GoRoute(path: '/categorias', builder: (_, _) => const Scaffold()),
      ],
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringChargesCatchUpProvider.overrideWith((ref) async => const RecurringChargeReport()),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          allIncomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          subscriptionsProvider.overrideWith((ref) => Stream.value(<Subscription>[])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(<InstallmentPurchase>[])),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            container = ProviderScope.containerOf(context);
            return MaterialApp.router(
              routerConfig: router,
              theme: AppTheme.light(),
              locale: const Locale('pt'),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  String? focusedFieldLabel(WidgetTester tester) {
    final focused = tester.widgetList<TextField>(find.byType(TextField)).where((f) => f.focusNode?.hasFocus ?? false);
    return focused.isEmpty ? null : focused.first.decoration?.labelText;
  }

  testWidgets('o Dashboard tem "Lançar receita" e "Lançar gasto" logo abaixo do saldo', (tester) async {
    await pumpApp(tester);

    expect(find.widgetWithText(FilledButton, 'Lançar receita'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Lançar gasto'), findsOneWidget);
  });

  testWidgets('"Lançar receita" abre Receitas com o cursor no Valor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Lançar receita'));
    await tester.pumpAndSettle();

    expect(find.text('Receitas lançadas'), findsOneWidget);
    expect(focusedFieldLabel(tester), 'Valor');
    expect(container.read(focusRequestProvider), isNull, reason: 'o pedido é consumido');
  });

  testWidgets('"Lançar gasto" abre Gastos com o cursor no Valor', (tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Lançar gasto'));
    await tester.pumpAndSettle();

    expect(find.text('Gastos lançados'), findsOneWidget);
    expect(focusedFieldLabel(tester), 'Valor');
    expect(container.read(focusRequestProvider), isNull);
  });

  testWidgets('o título do menu tem o chip do chevron e área de toque de pelo menos 48 dp', (tester) async {
    await pumpApp(tester);

    expect(find.byType(MenuChevronChip), findsOneWidget);
    final title = tester.getRect(find.descendant(of: find.byType(InkWell), matching: find.byType(MenuChevronChip)).first);
    final inkWell = tester.getRect(find.ancestor(of: find.byType(MenuChevronChip), matching: find.byType(InkWell)).first);
    expect(title.width, 30);
    expect(inkWell.height, greaterThanOrEqualTo(48));
  });
}
