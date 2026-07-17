import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

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

  group('CaixinhaDebtIndicator', () {
    Future<void> pumpDebt(WidgetTester tester, {required double balance}) {
      return tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
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
