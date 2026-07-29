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
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';

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
}
