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

  testWidgets('a barra mostra os 5 destinos de dinheiro mais o logo', (tester) async {
    await pump(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(6), reason: '5 destinos + o botão do logo');

    for (final label in ['Dashboard', 'Receitas', 'Gastos', 'Assinaturas', 'Parcelas']) {
      expect(find.text(label), findsWidgets, reason: '$label deve estar na barra');
    }
    expect(find.text('Mais'), findsOneWidget);
    // Categorias e Ajustes saíram da barra — são gerenciamento, não rotina.
    expect(find.text('Categorias'), findsNothing);
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('tocar num destino da barra troca de página', (tester) async {
    await pump(tester);
    expect(find.text('page:dashboard'), findsOneWidget);

    await tester.tap(find.text('Assinaturas'));
    await tester.pumpAndSettle();

    expect(find.text('page:assinaturas'), findsOneWidget);
    expect(find.text('page:dashboard'), findsNothing);
  });

  testWidgets('o logo abre a folha com Categorias e Ajustes', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('escolher na folha navega e fecha a folha', (tester) async {
    await pump(tester);

    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('page:ajustes'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing, reason: 'a folha fechou');
  });

  testWidgets('estando numa tela de trás do logo, é o logo que aparece selecionado', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorias'));
    await tester.pumpAndSettle();

    // Índice 5 é o slot do logo. Sem esse clamp o NavigationBar receberia um
    // selectedIndex fora da faixa (a branch de Categorias é a 5 de 7) e
    // estouraria.
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 5);
    expect(find.text('page:categorias'), findsOneWidget);
  });

  testWidgets('em tela larga o rail mostra os 7 destinos, sem botão de "Mais"', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(7), reason: 'uma lista vertical comporta todos');
    expect(find.text('Categorias'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
    expect(find.text('Mais'), findsNothing);
  });
}
