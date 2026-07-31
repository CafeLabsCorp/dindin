// Widget tests for the Assinaturas screen (moved off the bottom of Gastos —
// see AssinaturasPage's doc comment for why it got its own route).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:dindin/features/assinaturas/assinaturas_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';
import 'package:dindin/theme/theme.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  const gastar = Category(
    id: 'c1',
    name: 'Lazer',
    recurring: false,
    createdAt: '2026-01-01',
    kind: CategoryKind.spend,
  );
  const guardar = Category(
    id: 'c2',
    name: 'Viagem',
    recurring: false,
    createdAt: '2026-01-01',
    kind: CategoryKind.save,
  );

  Future<void> pump(
    WidgetTester tester, {
    List<Subscription> subscriptions = const [],
    List<Category> categories = const [gastar, guardar],
    // Pinned so "how many charges are pending" — a function of the current
    // date — can't drift as real time passes.
    DateTime? today,
    bool catchUpFailed = false,
  }) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          categoriesProvider.overrideWith((ref) => Stream.value(categories)),
          subscriptionsProvider.overrideWith((ref) => Stream.value(subscriptions)),
          todayProvider.overrideWithValue(today ?? DateTime(2026, 1, 1)),
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
          home: const Scaffold(body: AssinaturasPage()),
        ),
      ),
    );
  }

  testWidgets('sem nenhuma assinatura cadastrada mostra o estado vazio', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    expect(find.text('Nenhuma assinatura cadastrada ainda.'), findsOneWidget);
  });

  testWidgets('assinatura da conta mostra dia de cobrança e origem', (tester) async {
    await pump(
      tester,
      subscriptions: const [
        Subscription(id: 's1', name: 'Netflix', amount: 39.90, dueDay: 5, createdAt: '2026-01-01'),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Cobra todo dia 5'), findsOneWidget);
    expect(find.textContaining('Conta'), findsWidgets);
    expect(find.byTooltip('Editar assinatura'), findsOneWidget);
    expect(find.byTooltip('Remover assinatura'), findsOneWidget);
  });

  testWidgets('assinatura de caixinha mostra o nome da caixinha como origem', (tester) async {
    await pump(
      tester,
      subscriptions: const [
        Subscription(
          id: 's1',
          name: 'Netflix',
          amount: 39.90,
          dueDay: 5,
          createdAt: '2026-01-01',
          categoryId: 'c1',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('Lazer'), findsWidgets);
  });

  testWidgets('caixinha removida avisa em vez de deixar a cobrança sumir calada', (tester) async {
    await pump(
      tester,
      subscriptions: const [
        Subscription(
          id: 's1',
          name: 'Netflix',
          amount: 39.90,
          dueDay: 5,
          createdAt: '2026-01-01',
          categoryId: 'sumiu',
        ),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('caixinha dessa cobrança foi removida'), findsOneWidget);
  });

  testWidgets('só caixinhas do tipo gastar aparecem como origem', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Sai de'));
    await tester.pumpAndSettle();

    expect(find.text('Lazer'), findsWidgets, reason: 'caixinha de gastar é elegível');
    expect(
      find.text('Viagem'),
      findsNothing,
      reason: 'caixinha de guardar é meta de poupança, não fonte de assinatura',
    );
  });

  testWidgets('cobranças que não couberam no saldo aparecem na linha', (tester) async {
    await pump(
      tester,
      subscriptions: const [
        Subscription(id: 's1', name: 'Netflix', amount: 39.90, dueDay: 5, createdAt: '2026-01-01'),
      ],
      today: DateTime(2026, 3, 20),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 cobranças pendentes'), findsOneWidget);
  });

  testWidgets('adicionar assinatura sem nome mostra o erro de nome obrigatório', (tester) async {
    await pump(tester);
    await tester.pumpAndSettle();

    final addButton = find.widgetWithText(FilledButton, 'Adicionar assinatura');
    await tester.ensureVisible(addButton);
    await tester.pumpAndSettle();
    await tester.tap(addButton);
    await tester.pumpAndSettle();

    expect(find.text('Informe um nome.'), findsOneWidget);
  });

  testWidgets('editar abre a folha já preenchida com os valores atuais', (tester) async {
    await pump(
      tester,
      subscriptions: const [
        Subscription(id: 's1', name: 'Netflix', amount: 39.90, dueDay: 5, createdAt: '2026-01-01'),
      ],
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar assinatura'));
    await tester.pumpAndSettle();

    expect(find.text('Editar assinatura'), findsWidgets);
    expect(find.text('Netflix'), findsWidgets);
    expect(find.text('39,90'), findsOneWidget);
    // Mudar o dia não mexe em mês já cobrado — a folha diz isso.
    expect(find.textContaining('vale a partir do próximo mês'), findsOneWidget);
  });
}
