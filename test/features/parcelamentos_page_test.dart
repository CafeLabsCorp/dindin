// Widget tests for the Parcelamentos screen, including paying ahead and
// paying off (which shorten the schedule, not the installment — see
// recurring_schedule.outstandingAmount).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/parcelamentos/parcelamentos_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/utils/format.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const gastar = Category(
    id: 'c1',
    name: 'Eletrônicos',
    recurring: false,
    createdAt: '2026-01-01',
    kind: CategoryKind.spend,
  );

  // 1.000 em 10x de 100, 3 parcelas já cobradas -> faltam 700.
  const emAndamento = InstallmentPurchase(
    id: 'p1',
    name: 'Notebook Dell',
    totalAmount: 1000,
    installments: 10,
    purchaseDate: '2026-01-01',
    firstChargeDate: '2026-01-10',
    createdAt: '2026-01-01',
    chargedInstallments: 3,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<InstallmentPurchase> purchases = const [],
    List<Expense> expenses = const [],
    DateTime? today,
    bool catchUpFailed = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(const [gastar])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(purchases)),
          expensesProvider.overrideWith((ref) => Stream.value(expenses)),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 4, 1)),
          if (catchUpFailed)
            recurringChargesCatchUpProvider.overrideWith(
              (ref) => Future<RecurringChargeReport>.error(Exception('offline')),
            ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: ParcelamentosPage()),
        ),
      ),
    );
  }

  testWidgets('sem nenhum parcelamento cadastrado mostra o estado vazio', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum parcelamento cadastrado ainda.'), findsOneWidget);
  });

  testWidgets('mostra quanto ainda falta pagar, não só quantas parcelas', (tester) async {
    await pump(tester, purchases: const [emAndamento]);
    await tester.pumpAndSettle();

    expect(find.textContaining('Faltam'), findsOneWidget);
    expect(find.textContaining('700,00'), findsWidgets);
    expect(find.byTooltip('Pagar adiantado ou quitar'), findsOneWidget);
    expect(find.byTooltip('Remover parcelamento'), findsOneWidget);
  });

  testWidgets('um parcelamento com pagamento adiantado mostra o quanto foi adiantado', (tester) async {
    await pump(
      tester,
      purchases: const [
        InstallmentPurchase(
          id: 'p1',
          name: 'Notebook Dell',
          totalAmount: 1000,
          installments: 10,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-01-10',
          createdAt: '2026-01-01',
          chargedInstallments: 3,
          amortizedAmount: 300,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('300,00 pagos adiantado'), findsOneWidget);
    // 1000 - 300 cobrados - 300 adiantados = 400.
    expect(find.textContaining('400,00'), findsWidgets);
  });

  testWidgets('quitado esconde o botão de pagar e diz que acabou', (tester) async {
    await pump(
      tester,
      purchases: const [
        InstallmentPurchase(
          id: 'p1',
          name: 'Notebook Dell',
          totalAmount: 1000,
          installments: 10,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-01-10',
          createdAt: '2026-01-01',
          chargedInstallments: 3,
          amortizedAmount: 700,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Quitado'), findsOneWidget);
    expect(find.byTooltip('Pagar adiantado ou quitar'), findsNothing);
  });

  testWidgets('a folha de pagamento oferece quitar pelo saldo devedor exato', (tester) async {
    await pump(tester, purchases: const [emAndamento]);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Pagar adiantado ou quitar'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Pagar Notebook Dell'), findsOneWidget);
    // O texto explica que encurta o prazo, não a parcela.
    expect(find.textContaining('encurta o prazo'), findsOneWidget);
    expect(find.textContaining('Quitar tudo'), findsOneWidget);
    expect(find.textContaining('700,00'), findsWidgets);
  });

  testWidgets('mostra o progresso de parcelas pagas', (tester) async {
    await pump(tester, purchases: const [emAndamento]);
    await tester.pumpAndSettle();

    expect(find.text('3 de 10 parcelas pagas'), findsOneWidget);
  });

  testWidgets('o valor de cada parcela só aparece depois de expandir a lista', (tester) async {
    // 140,90 em 6x -> 23,49 nas duas primeiras, 23,48 nas outras quatro
    // (resto do arredondamento nas primeiras parcelas).
    await pump(
      tester,
      purchases: const [
        InstallmentPurchase(
          id: 'p1',
          name: 'Fone',
          totalAmount: 140.90,
          installments: 6,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-01-10',
          createdAt: '2026-01-01',
          chargedInstallments: 2,
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(
      find.text(formatCurrency(23.49)),
      findsNothing,
      reason: 'recolhido por padrão',
    );

    await tester.tap(find.text('Ver parcelas'));
    await tester.pumpAndSettle();

    expect(find.text(formatCurrency(23.49)), findsNWidgets(2));
    expect(find.text(formatCurrency(23.48)), findsNWidgets(4));
    expect(
      find.byIcon(Icons.check),
      findsNWidgets(2),
      reason: 'as 2 primeiras parcelas já foram cobradas',
    );

    await tester.tap(find.text('Ocultar parcelas'));
    await tester.pumpAndSettle();

    expect(find.text(formatCurrency(23.49)), findsNothing);
  });

  testWidgets('adicionar parcelamento sem nome mostra o erro de nome obrigatório', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Adicionar parcelamento');
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe um nome.'), findsOneWidget);
  });

  testWidgets('cada parcela mostra o vencimento, e as pagas mostram o dia real', (tester) async {
    await pump(
      tester,
      purchases: [emAndamento],
      // A cobrança roda quando o app abre, então a parcela 1 venceu dia 10 e
      // só foi lançada dia 12 — é essa diferença que justifica as duas datas.
      expenses: const [
        Expense(
          id: 'e1',
          date: '2026-01-12',
          amount: 100,
          description: 'Notebook Dell (1/10)',
          sourceType: 'installment',
          sourceId: 'p1',
        ),
      ],
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ver parcelas'));
    await tester.pumpAndSettle();

    expect(find.textContaining('vence 10/01'), findsWidgets);
    expect(find.textContaining('pago 12/01'), findsOneWidget);
    // A parcela 4 ainda não foi cobrada: vencimento sim, dia pago não.
    expect(find.textContaining('vence 10/04'), findsOneWidget);
  });

}
