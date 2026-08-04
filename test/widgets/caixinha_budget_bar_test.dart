import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/utils/format.dart';
import 'package:dindin/widgets/caixinha_budget_bar.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  Future<void> pump(WidgetTester tester, {required double spent, required double limit}) {
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: CaixinhaBudgetBar(spent: spent, limit: limit)),
      ),
    );
  }

  testWidgets('abaixo de 80%: barra neutra, sem aviso de estouro', (tester) async {
    await pump(tester, spent: 50, limit: 200); // 25%

    expect(find.text('Gasto: ${formatCurrency(50)} de ${formatCurrency(200)} este mês'), findsOneWidget);
    expect(find.textContaining('acima do limite'), findsNothing);

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, closeTo(0.25, 0.001));
  });

  testWidgets('entre 80% e 100%: mostra aviso mas não de estouro', (tester) async {
    await pump(tester, spent: 90, limit: 100); // 90%

    expect(find.text('Gasto: ${formatCurrency(90)} de ${formatCurrency(100)} este mês'), findsOneWidget);
    expect(find.textContaining('acima do limite'), findsNothing);
  });

  testWidgets('acima de 100%: barra capada em 100% e mostra quanto passou', (tester) async {
    await pump(tester, spent: 150, limit: 100); // 150%

    expect(find.text('Gasto: ${formatCurrency(150)} de ${formatCurrency(100)} este mês'), findsOneWidget);
    expect(find.text('+${formatCurrency(50)} acima do limite'), findsOneWidget);

    final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
    expect(indicator.value, 1.0); // nunca passa de 100% de largura
  });

  group('CaixinhaGoalBar', () {
    Future<void> pumpGoal(
      WidgetTester tester, {
      required double saved,
      required double goal,
      bool monthly = false,
    }) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CaixinhaGoalBar(saved: saved, goal: goal, monthly: monthly)),
        ),
      );
    }

    testWidgets('monthly=false (padrão): legenda não menciona mês — meta acumulada de sempre', (tester) async {
      await pumpGoal(tester, saved: 300, goal: 1000);

      expect(find.text('${formatCurrency(300)} de ${formatCurrency(1000)} guardados (30%)'), findsOneWidget);
      expect(find.textContaining('este mês'), findsNothing);
    });

    testWidgets('monthly=false atingida: "Meta atingida", sem menção a mês', (tester) async {
      await pumpGoal(tester, saved: 1000, goal: 1000);

      expect(find.text('Meta atingida: ${formatCurrency(1000)} de ${formatCurrency(1000)} guardados'), findsOneWidget);
    });

    testWidgets('monthly=true: legenda deixa explícito que é o progresso do mês', (tester) async {
      await pumpGoal(tester, saved: 300, goal: 800, monthly: true);

      expect(
        find.text('${formatCurrency(300)} de ${formatCurrency(800)} guardados este mês (38%)'),
        findsOneWidget,
      );
    });

    testWidgets('monthly=true atingida: "Meta do mês batida", distinta da versão sem mês', (tester) async {
      await pumpGoal(tester, saved: 800, goal: 800, monthly: true);

      expect(
        find.text('Meta do mês batida: ${formatCurrency(800)} de ${formatCurrency(800)} guardados'),
        findsOneWidget,
      );
      expect(find.textContaining('Meta atingida:'), findsNothing);
    });

    testWidgets('a barra em si (ratio/cor) não muda com monthly — só a legenda', (tester) async {
      await pumpGoal(tester, saved: 400, goal: 800, monthly: true);
      final indicator = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect(indicator.value, closeTo(0.5, 0.001));
    });
  });

  group('CaixinhaDebtIndicator', () {
    Future<void> pumpDebt(WidgetTester tester, {required double balance}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: CaixinhaDebtIndicator(balance: balance)),
        ),
      );
    }

    testWidgets('saldo negativo: mostra "Devendo" com o valor em módulo', (tester) async {
      await pumpDebt(tester, balance: -42.5);
      expect(find.text('Devendo ${formatCurrency(42.5)}'), findsOneWidget);
    });

    testWidgets('saldo zero ou positivo: não renderiza nada', (tester) async {
      await pumpDebt(tester, balance: 0);
      expect(find.textContaining('Devendo'), findsNothing);

      await pumpDebt(tester, balance: 10);
      expect(find.textContaining('Devendo'), findsNothing);
    });
  });
}
