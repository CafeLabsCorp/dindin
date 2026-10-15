// Layout sweep: every main screen rendered at phone-to-tablet widths, with the
// system font enlarged, in both languages. Catches what a single-size widget
// test can't — RenderFlex overflows and rows squeezed by their own actions
// (the "Cobrar agora" button once crushed the subscription name into a
// sliver; the idioma check once broke "Português" over two lines).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/assinaturas/assinaturas_page.dart';
import 'package:dindin/features/auth/login_page.dart';
import 'package:dindin/features/categorias/categorias_page.dart';
import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/features/parcelamentos/parcelamentos_page.dart';
import 'package:dindin/features/receitas/receitas_page.dart';
import 'package:dindin/features/settings/settings_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/providers/locale_provider.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/auth_service.dart';
import 'package:dindin/theme/theme.dart';

class _MockAuthService extends Mock implements AuthService {}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await initializeDateFormatting('en');
  });

  const casa = Category(
    id: 'c1',
    name: 'Casa com um nome bem comprido de caixinha',
    recurring: true,
    createdAt: '2026-01-01',
    monthlyBudget: 1500,
  );
  const viagem = Category(
    id: 'c2',
    name: 'Viagem',
    recurring: false,
    createdAt: '2026-01-01',
    kind: CategoryKind.save,
    goalAmount: 8000,
  );
  const categories = [casa, viagem];
  const incomes = [
    Income(
      id: 'i1',
      date: '2026-01-05',
      amount: 12345.67,
      source: IncomeSource.freela,
      description: 'Freela de fim de semana com descrição longa',
    ),
  ];
  const expenses = [
    Expense(
      id: 'e1',
      date: '2026-01-05',
      amount: 1280.5,
      categoryId: 'c1',
      description: 'Mercado do mês com descrição bem longa mesmo',
    ),
  ];
  const allocations = <Allocation>[];
  const subscriptions = [
    Subscription(
      id: 's1',
      name: 'Netflix Premium',
      amount: 258.88,
      dueDay: 9,
      createdAt: '2026-01-01',
      autoChargeEnabled: false,
    ),
  ];
  const purchases = [
    InstallmentPurchase(
      id: 'p1',
      name: 'Notebook Dell',
      totalAmount: 7999.9,
      installments: 12,
      purchaseDate: '2026-01-01',
      firstChargeDate: '2026-01-10',
      createdAt: '2026-01-01',
      chargedInstallments: 3,
    ),
  ];

  // Every screen reads the shared data below, so no per-screen overrides.
  final screens = <String, Widget>{
    'assinaturas': const AssinaturasPage(),
    'parcelamentos': const ParcelamentosPage(),
    'gastos': const GastosPage(),
    'receitas': const ReceitasPage(),
    'categorias': const CategoriasPage(),
    'dashboard': const DashboardPage(),
  };

  final shared = <Override>[
    categoriesProvider.overrideWith((ref) => Stream.value(categories)),
    incomesProvider.overrideWith((ref) => Stream.value(incomes)),
    expensesProvider.overrideWith((ref) => Stream.value(expenses)),
    allocationsProvider.overrideWith((ref) => Stream.value(allocations)),
    allIncomesProvider.overrideWith((ref) => Stream.value(incomes)),
    allExpensesProvider.overrideWith((ref) => Stream.value(expenses)),
    allAllocationsProvider.overrideWith((ref) => Stream.value(allocations)),
    subscriptionsProvider.overrideWith((ref) => Stream.value(subscriptions)),
    installmentPurchasesProvider.overrideWith((ref) => Stream.value(purchases)),
    todayProvider.overrideWithValue(DateTime(2026, 1, 15)),
  ];

  Future<void> pumpScreen(
    WidgetTester tester, {
    required Widget page,
    required List<Override> overrides,
    required double width,
    required double scale,
    required Locale locale,
  }) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = Size(width, 900);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [...shared, ...overrides],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(body: page),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  const widths = [320.0, 360.0, 412.0, 600.0, 900.0];
  const scales = [1.0, 1.3];
  const locales = [Locale('pt'), Locale('en')];

  for (final entry in screens.entries) {
    for (final locale in locales) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets(
            '${entry.key} sem overflow — ${locale.languageCode}, ${width.toInt()}px, fonte x$scale',
            (tester) async {
              await pumpScreen(
                tester,
                page: entry.value,
                overrides: const [],
                width: width,
                scale: scale,
                locale: locale,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }

  // Login and Settings need an auth service, so they build their own overrides.
  Map<String, ({Widget page, List<Override> overrides})> authScreens() {
    final auth = _MockAuthService();
    when(() => auth.reloadCurrentUser()).thenAnswer((_) async {});
    return {
      'login': (
        page: const LoginPage(),
        overrides: [authServiceProvider.overrideWith((ref) => auth)],
      ),
      'settings': (
        page: const SettingsPage(),
        overrides: [
          authStateProvider.overrideWith((ref) => Stream.value(null)),
          authServiceProvider.overrideWith((ref) => auth),
        ],
      ),
    };
  }

  for (final name in ['login', 'settings']) {
    for (final locale in locales) {
      for (final width in widths) {
        for (final scale in scales) {
          testWidgets(
            '$name sem overflow — ${locale.languageCode}, ${width.toInt()}px, fonte x$scale',
            (tester) async {
              final screen = authScreens()[name]!;
              await pumpScreen(
                tester,
                page: screen.page,
                overrides: [
                  ...screen.overrides,
                  localeProvider.overrideWith((ref) => locale),
                ],
                width: width,
                scale: scale,
                locale: locale,
              );
              expect(tester.takeException(), isNull);
            },
          );
        }
      }
    }
  }
}
