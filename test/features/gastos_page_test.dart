import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/gastos/gastos_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const casa = Category(id: 'c1', name: 'Casa', recurring: true, createdAt: '2026-01-01');
  const expense = Expense(id: 'e1', date: '2026-07-05', amount: 80, categoryId: 'c1', description: 'Mercado');

  Future<void> pump(
    WidgetTester tester, {
    required List<Expense> expenses,
    List<Subscription> subscriptions = const [],
    List<InstallmentPurchase> installmentPurchases = const [],
    // Pinned by default so "how many charges are still pending" — a function
    // of the current date — can't drift as real time passes. Tests that care
    // about pending charges pass their own date.
    DateTime? today,
    // Simulates catch-up itself blowing up, which the page reports
    // differently from "catch-up finished and these didn't fit the balance".
    bool catchUpFailed = false,
  }) async {
    // GastosPage's ListView now has 4 cards (gasto, lista, assinaturas,
    // parcelamentos) — taller than the default 600px test surface, and a
    // sliver list only builds Elements for children within the viewport +
    // cache extent. Without a tall-enough surface, find.text() on the last
    // card's content returns 0 matches (the Element genuinely doesn't exist
    // yet), not because anything is broken.
    await tester.binding.setSurfaceSize(const Size(800, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([casa])),
          expensesProvider.overrideWith((ref) => Stream.value(expenses)),
          subscriptionsProvider.overrideWith((ref) => Stream.value(subscriptions)),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(installmentPurchases)),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 1, 1)),
          if (catchUpFailed)
            recurringChargesCatchUpProvider.overrideWith(
              (ref) => Future<void>.error(Exception('firestore unavailable')),
            ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: GastosPage()),
        ),
      ),
    );
  }

  /// Pumps with a caixinha whose running balance (allocations - expenses) is
  /// forced negative, to exercise the proactive "frozen debt" form gate
  /// (`_blockedByFrozenDebt` — decision #3: toggle off + already negative
  /// blocks further gastos). This is a client-side UX safeguard on top of
  /// the actual money-integrity boundary enforced in firestore.rules/
  /// FirestoreService — see test/rules/rules.test.mjs and
  /// firestore_service_test.dart for that layer.
  Future<void> pumpWithNegativeBalance(
    WidgetTester tester, {
    required Category category,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 3200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value([category])),
          incomesProvider.overrideWith(
            (ref) => Stream.value(const [
              Income(id: 'i1', date: '2026-01-01', amount: 100, source: IncomeSource.freela),
            ]),
          ),
          allocationsProvider.overrideWith(
            (ref) => Stream.value(const [
              Allocation(id: 'a1', categoryId: 'c1', amount: 10, date: '2026-01-02'),
            ]),
          ),
          expensesProvider.overrideWith(
            (ref) => Stream.value(const [
              Expense(id: 'e1', date: '2026-01-03', amount: 50, categoryId: 'c1'),
            ]),
          ),
          subscriptionsProvider.overrideWith((ref) => Stream.value(const [])),
          installmentPurchasesProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: GastosPage()),
        ),
      ),
    );
  }

  testWidgets('linha usa ícone de remover e tocar nela abre a edição', (tester) async {
    await pump(tester, expenses: [expense]);
    await tester.pumpAndSettle();

    expect(find.byTooltip('Remover gasto'), findsOneWidget);
    expect(find.text('Remover'), findsNothing);

    final rowFinder = find.ancestor(of: find.byTooltip('Remover gasto'), matching: find.byType(InkWell));
    await tester.tap(rowFinder);
    await tester.pumpAndSettle();

    expect(find.text('Editar gasto'), findsOneWidget);
    expect(find.text('80,00'), findsOneWidget);
    // A caixinha do gasto não pode ser trocada na edição (updateExpense rejeita
    // mover entre alvos) — deve aparecer como campo somente leitura, não um
    // dropdown editável.
    expect(find.text('Casa'), findsWidgets);
    expect(find.text('Não é possível mudar a caixinha por aqui — remova e lance de novo.'), findsOneWidget);
  });

  testWidgets('linha de filtro De/Até aparece acima da lista, sem "Limpar filtro" por padrão', (tester) async {
    await pump(tester, expenses: [expense]);
    await tester.pumpAndSettle();

    expect(find.text('De'), findsOneWidget);
    expect(find.text('Até'), findsOneWidget);
    expect(find.text('Limpar filtro'), findsNothing);
  });

  testWidgets('sem nenhum gasto lançado mostra o estado vazio padrão (não o filtrado)', (tester) async {
    await pump(tester, expenses: []);
    await tester.pumpAndSettle();

    expect(find.text('Nenhum gasto lançado ainda.'), findsOneWidget);
  });

  group('assinaturas', () {
    testWidgets('sem nenhuma assinatura cadastrada mostra o estado vazio', (tester) async {
      await pump(tester, expenses: []);
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma assinatura cadastrada ainda.'), findsOneWidget);
    });

    testWidgets('assinatura cadastrada aparece na lista com o dia de cobrança e ícone de remover', (tester) async {
      await pump(
        tester,
        expenses: [],
        subscriptions: const [
          Subscription(id: 's1', name: 'Netflix', amount: 39.90, dueDay: 5, createdAt: '2026-01-01'),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhuma assinatura cadastrada ainda.'), findsNothing);
      expect(find.text('Cobra todo dia 5'), findsOneWidget);
      expect(find.byTooltip('Remover assinatura'), findsOneWidget);
    });

    testWidgets('adicionar assinatura sem nome mostra o erro de nome obrigatório', (tester) async {
      await pump(tester, expenses: []);
      await tester.pumpAndSettle();

      final addButton = find.widgetWithText(FilledButton, 'Adicionar assinatura');
      await tester.ensureVisible(addButton); // a seção fica abaixo da dobra na ListView
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Informe um nome.'), findsOneWidget);
    });
  });

  group('cobranças pendentes (catch-up que não coube no saldo)', () {
    // Uma assinatura de 5 de janeiro, com o app aberto em 20 de março e nada
    // cobrado ainda: jan/fev/mar venceram e não entraram.
    const atrasada = Subscription(
      id: 's1',
      name: 'Netflix',
      amount: 39.90,
      dueDay: 5,
      createdAt: '2026-01-01',
    );

    testWidgets('assinatura com cobranças que não entraram mostra o aviso e a contagem na linha', (tester) async {
      await pump(
        tester,
        expenses: [],
        subscriptions: const [atrasada],
        today: DateTime(2026, 3, 20),
      );
      await tester.pumpAndSettle();

      expect(find.text('3 cobranças pendentes'), findsOneWidget);
      expect(
        find.textContaining('3 cobranças não foram lançadas porque o saldo da conta não cobriu'),
        findsOneWidget,
      );
    });

    testWidgets('o texto fica no singular com uma única cobrança pendente', (tester) async {
      await pump(
        tester,
        expenses: [],
        subscriptions: const [atrasada],
        today: DateTime(2026, 1, 20),
      );
      await tester.pumpAndSettle();

      expect(find.text('1 cobrança pendente'), findsOneWidget);
      expect(
        find.textContaining('1 cobrança não foi lançada porque o saldo da conta não cobriu'),
        findsOneWidget,
      );
    });

    testWidgets('sem nada pendente não mostra aviso nenhum', (tester) async {
      await pump(
        tester,
        expenses: [],
        subscriptions: const [
          Subscription(
            id: 's1',
            name: 'Netflix',
            amount: 39.90,
            dueDay: 5,
            createdAt: '2026-01-01',
            lastChargedDate: '2026-03-05',
          ),
        ],
        today: DateTime(2026, 3, 20),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('cobrança pendente'), findsNothing);
      expect(find.textContaining('cobranças pendentes'), findsNothing);
      expect(find.textContaining('não foram lançadas'), findsNothing);
    });

    testWidgets('parcelamento atrasado também conta as parcelas pendentes', (tester) async {
      await pump(
        tester,
        expenses: [],
        installmentPurchases: const [
          InstallmentPurchase(
            id: 'p1',
            name: 'Notebook Dell',
            totalAmount: 300,
            installments: 3,
            purchaseDate: '2026-01-10',
            firstChargeDate: '2026-02-05',
            createdAt: '2026-01-10',
            chargedInstallments: 1,
          ),
        ],
        today: DateTime(2026, 4, 20),
      );
      await tester.pumpAndSettle();

      // Parcelas 2/3 (05/03) e 3/3 (05/04) venceram e não foram cobradas.
      expect(find.text('2 cobranças pendentes'), findsOneWidget);
    });

    testWidgets('quando o catch-up falha, culpa a falha em vez do saldo', (tester) async {
      await pump(
        tester,
        expenses: [],
        subscriptions: const [atrasada],
        today: DateTime(2026, 3, 20),
        catchUpFailed: true,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Não deu pra processar as cobranças automáticas agora'), findsWidgets);
      // "Pendente" não significa nada enquanto o catch-up não terminou: não
      // dá pra dizer que o saldo é o culpado.
      expect(find.textContaining('não foram lançadas'), findsNothing);
      expect(find.text('3 cobranças pendentes'), findsNothing);
    });
  });

  group('gasto gerado automaticamente', () {
    testWidgets('gasto vindo de assinatura aparece com o marcador de automático', (tester) async {
      await pump(
        tester,
        expenses: const [
          Expense(
            id: 'e1',
            date: '2026-01-05',
            amount: 39.90,
            description: 'Netflix',
            sourceType: 'subscription',
            sourceId: 's1',
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lançado automaticamente por uma assinatura ou parcelamento'), findsOneWidget);
    });

    testWidgets('gasto digitado à mão não ganha o marcador', (tester) async {
      await pump(tester, expenses: const [expense]);
      await tester.pumpAndSettle();

      expect(find.byTooltip('Lançado automaticamente por uma assinatura ou parcelamento'), findsNothing);
    });
  });

  group('parcelamentos', () {
    testWidgets('sem nenhum parcelamento cadastrado mostra o estado vazio', (tester) async {
      await pump(tester, expenses: []);
      await tester.pumpAndSettle();

      expect(find.text('Nenhum parcelamento cadastrado ainda.'), findsOneWidget);
    });

    testWidgets('parcelamento cadastrado aparece na lista com o progresso e ícone de remover', (tester) async {
      await pump(
        tester,
        expenses: [],
        installmentPurchases: const [
          InstallmentPurchase(
            id: 'p1',
            name: 'Notebook Dell',
            totalAmount: 300,
            installments: 3,
            purchaseDate: '2026-01-10',
            firstChargeDate: '2026-02-05',
            createdAt: '2026-01-10',
            chargedInstallments: 1,
          ),
        ],
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum parcelamento cadastrado ainda.'), findsNothing);
      expect(find.text('1 de 3 parcelas pagas'), findsOneWidget);
      expect(find.byTooltip('Remover parcelamento'), findsOneWidget);
    });

    testWidgets('adicionar parcelamento sem nome mostra o erro de nome obrigatório', (tester) async {
      await pump(tester, expenses: []);
      await tester.pumpAndSettle();

      final addButton = find.widgetWithText(FilledButton, 'Adicionar parcelamento');
      await tester.ensureVisible(addButton); // a seção fica abaixo da dobra na ListView
      await tester.pumpAndSettle();
      await tester.tap(addButton);
      await tester.pumpAndSettle();

      expect(find.text('Informe um nome.'), findsOneWidget);
    });
  });

  group('bloqueio de dívida congelada (decisão #3: toggle off + já negativo)', () {
    Future<void> selectCasa(WidgetTester tester) async {
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Casa').last);
      await tester.pumpAndSettle();
    }

    testWidgets('caixinha negativa com allowNegative OFF: desabilita valor/descrição/botão e mostra o aviso', (tester) async {
      await pumpWithNegativeBalance(tester, category: casa); // allowNegative unset -> off
      await tester.pumpAndSettle();
      await selectCasa(tester);

      expect(
        find.text('Essa caixinha está devendo e não permite saldo negativo. Aloque para ela antes de lançar novos gastos, ou ligue "Permitir saldo negativo" na categoria.'),
        findsOneWidget,
      );

      final valorField = tester.widget<TextField>(
        find.ancestor(of: find.text('Valor'), matching: find.byType(TextField)).first,
      );
      expect(valorField.enabled, isFalse);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lançar gasto'));
      expect(button.onPressed, isNull);
    });

    testWidgets('caixinha negativa com allowNegative ON: NÃO bloqueia (dívida pode se aprofundar)', (tester) async {
      const casaComDivida = Category(
        id: 'c1',
        name: 'Casa',
        recurring: true,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      await pumpWithNegativeBalance(tester, category: casaComDivida);
      await tester.pumpAndSettle();
      await selectCasa(tester);

      expect(find.textContaining('não permite saldo negativo'), findsNothing);

      final button = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Lançar gasto'));
      expect(button.onPressed, isNotNull);
    });
  });
}
