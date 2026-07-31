// Navigation shape tests for AppShell.
//
// Seven top-level destinations don't fit a bottom NavigationBar (Material's
// ceiling is five), so the five money screens stay in the bar and the rest
// open from the logo button. These tests pin that split down, plus the thing
// that's easy to get subtly wrong: which slot reads as selected while the
// user is on a screen that lives behind the logo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/app_shell.dart';

void main() {
  /// Stand-ins for the real screens: this is about the shell's navigation,
  /// not what each page renders (those have their own tests).
  StatefulShellBranch branch(String path, String label) => StatefulShellBranch(
    routes: [GoRoute(path: path, builder: (context, state) => Center(child: Text('page:$label')))],
  );

  Future<void> pump(WidgetTester tester, {Size size = const Size(400, 800)}) async {
    // physicalSize + devicePixelRatio 1.0 (rather than setSurfaceSize, which
    // is physical pixels) so `size` IS the logical size the layout sees —
    // this test turns entirely on the 720px narrow/wide breakpoint.
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final router = GoRouter(
      initialLocation: '/',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) => AppShell(navigationShell: navigationShell),
          branches: [
            branch('/', 'dashboard'),
            branch('/receitas', 'receitas'),
            branch('/gastos', 'gastos'),
            branch('/assinaturas', 'assinaturas'),
            branch('/parcelamentos', 'parcelamentos'),
            branch('/categorias', 'categorias'),
            branch('/ajustes', 'ajustes'),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // AppShell watches the catch-up provider, which reaches Firestore
          // through the auth chain; without this the test would need a real
          // Firebase app just to draw a nav bar.
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

  testWidgets('no mobile não existe barra de baixo — tudo mora no menu', (tester) async {
    await pump(tester);

    expect(find.byType(NavigationBar), findsNothing);
    // Nada de destino solto na tela: a única porta é o botão do menu.
    expect(find.byTooltip('Menu'), findsOneWidget);
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

  testWidgets('a app bar diz em qual tela você está', (tester) async {
    await pump(tester);
    // Sem barra de baixo, esse título é o único indicador de posição.
    expect(find.text('Dashboard'), findsOneWidget);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Parcelamentos'));
    await tester.pumpAndSettle();

    expect(find.text('page:parcelamentos'), findsOneWidget);
    expect(find.text('Parcelamentos'), findsOneWidget, reason: 'agora é o título da app bar');
  });

  testWidgets('escolher no menu navega e fecha o menu', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('page:ajustes'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing, reason: 'o menu fechou');
  });

  testWidgets('o menu marca a tela atual', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Menu'));
    await tester.pumpAndSettle();

    final tiles = tester.widgetList<ListTile>(find.byType(ListTile)).toList();
    expect(tiles.where((t) => t.selected), hasLength(1));
    expect(tiles.first.selected, isTrue, reason: 'Dashboard é a tela inicial');
  });

  testWidgets('em tela larga o rail mostra os 7 destinos, sem menu', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(7), reason: 'uma lista vertical comporta todos');
    expect(find.byTooltip('Menu'), findsNothing, reason: 'o rail já é a navegação');
  });
}
