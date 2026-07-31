// Navigation shape tests for AppShell.
//
// On narrow screens there is no app bar and no bottom bar: every destination
// lives in one menu, opened from the page's own title (see PageHeader). These
// tests exercise that whole chain — AppShell -> AppNavigation -> PageHeader —
// rather than stubbing the header out, because the wiring between them is
// exactly what broke while this shape was being found.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_shell.dart';
import 'package:dindin/widgets/page_header.dart';

void main() {
  /// Stand-in for a real screen: a PageHeader (the menu trigger) plus a body
  /// marker. Titles match the nav labels, exactly as the real pages do.
  StatefulShellBranch branch(String path, String title) => StatefulShellBranch(
    routes: [
      GoRoute(
        path: path,
        builder: (context, state) => ListView(
          children: [
            PageHeader(
              title: title,
              subtitle: 'sub',
              onOpenMenu: AppNavigation.of(context)?.openMenu,
              menuLabel: 'Menu',
            ),
            Text('page:$title'),
          ],
        ),
      ),
    ],
  );

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    // physicalSize + devicePixelRatio 1.0 (rather than setSurfaceSize, which
    // is physical pixels) so `size` IS the logical size the layout sees —
    // these tests turn on the 720px narrow/wide breakpoint.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            branch('/', 'Dashboard'),
            branch('/receitas', 'Receitas'),
            branch('/gastos', 'Gastos'),
            branch('/assinaturas', 'Assinaturas'),
            branch('/parcelamentos', 'Parcelamentos'),
            branch('/categorias', 'Categorias'),
            branch('/ajustes', 'Ajustes'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // AppShell watches the catch-up provider, which reaches Firestore
          // through the auth chain; without this the test would need a real
          // Firebase app just to draw navigation.
          firestoreServiceProvider.overrideWithValue(null),
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

  testWidgets('no mobile não há barra nem app bar — o título é a navegação', (tester) async {
    await pump(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(AppBar), findsNothing);
    expect(find.byTooltip('Menu'), findsOneWidget);
  });

  testWidgets('o nome da tela aparece UMA vez, não duas', (tester) async {
    // Regressão do que o usuário viu: a app bar dizia "Dashboard" e o corpo
    // dizia "Dashboard" de novo, uma linha abaixo.
    await pump(tester);

    expect(find.text('Dashboard'), findsOneWidget);
  });

  testWidgets('o menu lista TODOS os sete destinos, sem subconjunto escondido', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    for (final label in [
      'Dashboard',
      'Receitas',
      'Gastos',
      'Assinaturas',
      'Parcelamentos',
      'Categorias',
      'Ajustes',
    ]) {
      expect(
        find.descendant(of: find.byType(ListTile), matching: find.text(label)),
        findsOneWidget,
        reason: '$label precisa estar no menu',
      );
    }
  });

  testWidgets('escolher no menu navega e fecha o menu', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('page:Ajustes'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing, reason: 'o menu fechou');
    // E o título da nova tela vira o gatilho, sem duplicar.
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('o menu marca a tela atual', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.where((t) => t.selected), hasLength(1));
    expect(tiles.first.selected, isTrue, reason: 'Dashboard é a tela inicial');
  });

  testWidgets('tocar fora fecha o menu sem navegar', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    // O scrim escurecido é dismissível — parte do "é modal, a página está atrás".
    await tester.tapAt(const Offset(200, 780));
    await tester.pumpAndSettle();

    expect(find.byType(ListTile), findsNothing);
    expect(find.text('page:Dashboard'), findsOneWidget);
  });

  testWidgets('em tela larga o rail é a navegação e o título não abre menu', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(7), reason: 'uma lista vertical comporta todos');
    expect(
      find.byTooltip('Menu'),
      findsNothing,
      reason: 'com o rail visível, um menu no título seria redundante',
    );
  });
}
