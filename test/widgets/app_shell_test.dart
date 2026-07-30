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

  testWidgets('a barra mostra exatamente os 5 destinos de dinheiro', (tester) async {
    await pump(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.destinations, hasLength(5), reason: 'o logo NÃO ocupa slot da barra');

    for (final label in ['Dashboard', 'Receitas', 'Gastos', 'Fixos', 'Parcelas']) {
      expect(find.text(label), findsWidgets, reason: '$label deve estar na barra');
    }
    // Categorias e Ajustes saíram da barra — são gerenciamento, não rotina.
    expect(find.text('Categorias'), findsNothing);
    expect(find.text('Ajustes'), findsNothing);
  });

  testWidgets('nenhum rótulo destoa em altura num celular estreito', (tester) async {
    // Regressão real: com o logo ocupando um sexto slot, cada um ficava com
    // ~63px e "Assinaturas" quebrava no meio da palavra ("Assinatura" / "s").
    //
    // A comparação é RELATIVA de propósito. A fonte do flutter_test é
    // sintética (glifos de largura fixa), então altura absoluta aqui não diz
    // nada sobre o navegador — o que diz é um rótulo ficar mais alto que os
    // outros, que foi exatamente como o bug apareceu.
    await pump(tester, size: const Size(360, 780));

    final heights = <String, double>{};
    for (final label in ['Dashboard', 'Receitas', 'Gastos', 'Fixos', 'Parcelas']) {
      final finder = find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(label),
      );
      expect(finder, findsOneWidget, reason: '$label deve estar na barra');
      heights[label] = tester.renderObject<RenderBox>(finder).size.height;
    }

    final shortest = heights.values.reduce((a, b) => a < b ? a : b);
    for (final entry in heights.entries) {
      expect(
        entry.value,
        lessThanOrEqualTo(shortest * 2),
        reason: '"${entry.key}" ficou desproporcionalmente alto — indício de quebra',
      );
    }
  });

  testWidgets('tocar num destino da barra troca de página', (tester) async {
    await pump(tester);
    expect(find.text('page:dashboard'), findsOneWidget);

    await tester.tap(find.text('Fixos'));
    await tester.pumpAndSettle();

    expect(find.text('page:assinaturas'), findsOneWidget);
    expect(find.text('page:dashboard'), findsNothing);
  });

  testWidgets('o logo abre a folha com Categorias e Ajustes', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();

    expect(find.text('Categorias'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
  });

  testWidgets('escolher na folha navega e fecha a folha', (tester) async {
    await pump(tester);

    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ajustes'));
    await tester.pumpAndSettle();

    expect(find.text('page:ajustes'), findsOneWidget);
    expect(find.byType(ListTile), findsNothing, reason: 'a folha fechou');
  });

  testWidgets('estando numa tela de trás do logo, é o logo que aparece selecionado', (tester) async {
    await pump(tester);
    await tester.tap(find.byTooltip('Mais'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Categorias'));
    await tester.pumpAndSettle();

    // A branch de Categorias é a 5 (de 7), fora da faixa da barra de 5 slots:
    // sem o clamp o NavigationBar estouraria. Quem sinaliza onde você está de
    // verdade é o chevron do logo, que fica na cor primária.
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, lessThan(5));
    expect(find.text('page:categorias'), findsOneWidget);
  });

  testWidgets('em tela larga o rail mostra os 7 destinos, sem botão de "Mais"', (tester) async {
    await pump(tester, size: const Size(1200, 900));

    expect(find.byType(NavigationBar), findsNothing);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(7), reason: 'uma lista vertical comporta todos');
    expect(find.text('Categorias'), findsWidgets);
    expect(find.text('Ajustes'), findsWidgets);
    expect(find.byTooltip('Mais'), findsNothing, reason: 'sem overflow em tela larga');
  });
}
