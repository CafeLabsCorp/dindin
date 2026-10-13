// Pull-to-refresh on the Dashboard re-runs the recurring-charge catch-up,
// which otherwise only runs once per app open.
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
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('arrastar pra baixo roda o catch-up de assinaturas e parcelas de novo', (tester) async {
    var runs = 0;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          recurringChargesCatchUpProvider.overrideWith((ref) async {
            runs++;
            return const RecurringChargeReport();
          }),
          categoriesProvider.overrideWith((ref) => Stream.value(<Category>[])),
          allocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          incomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          expensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
          allAllocationsProvider.overrideWith((ref) => Stream.value(<Allocation>[])),
          allIncomesProvider.overrideWith((ref) => Stream.value(<Income>[])),
          allExpensesProvider.overrideWith((ref) => Stream.value(<Expense>[])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          // O catch-up é assistido pelo AppShell em produção; aqui o teste o
          // lê direto pra o provider ficar vivo e contar as execuções.
          home: Consumer(
            builder: (context, ref, _) {
              ref.watch(recurringChargesCatchUpProvider);
              return const Scaffold(body: DashboardPage());
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(runs, 1);

    await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
    await tester.pumpAndSettle();

    expect(runs, 2, reason: 'o gesto dispara o mesmo catch-up da abertura do app');
  });
}
