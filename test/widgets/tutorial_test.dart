// The onboarding tutorial engine (docs/onboarding-design.md, direction A).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/theme/theme.dart';
import 'package:dindin/widgets/tutorial/tutorial.dart';

void main() {
  final titleKey = GlobalKey();
  final buttonKey = GlobalKey();
  final farKey = GlobalKey();
  TutorialResult? result;
  var targetTaps = 0;

  /// A page with a title near the top, a button, and a card far below the fold
  /// inside a scrollable (the last step has to scroll to it).
  Future<void> pumpHost(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double textScale = 1.0,
    bool reduceMotion = false,
    ThemeMode themeMode = ThemeMode.light,
    List<TutorialStep>? steps,
    Widget Function(Widget child)? wrap,
  }) async {
    result = null;
    targetTaps = 0;
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final theSteps = steps ??
        [
          TutorialStep(target: titleKey, title: 'O nome da página', body: 'Toque aqui para abrir o menu.', onTargetTap: () => targetTaps++),
          TutorialStep(target: buttonKey, title: 'Lance aqui', body: 'Preencha o valor e de onde veio.', radius: 24),
          TutorialStep(target: farKey, title: 'Sua lista', body: 'Cada lançamento aparece aqui.', radius: 16),
        ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale), disableAnimations: reduceMotion),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            // A scroll view that builds every child (a plain ListView builds
            // lazily, and a far-below widget wouldn't exist yet).
            body: SingleChildScrollView(
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('Receitas', key: titleKey, style: const TextStyle(fontSize: 28)),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton(key: buttonKey, onPressed: () {}, child: const Text('Adicionar')),
                ),
                TextButton(
                  onPressed: () async => result = await showTutorial(context, pageName: 'Receitas', steps: theSteps),
                  child: const Text('começar'),
                ),
                const SizedBox(height: 1500),
                Card(key: farKey, child: const SizedBox(height: 80, child: Center(child: Text('lista')))),
                const SizedBox(height: 400),
              ],
            ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> start(WidgetTester tester) async {
    await tester.tap(find.text('começar'));
    await tester.pumpAndSettle();
  }

  testWidgets('mostra o primeiro passo: número, título, texto e contador', (tester) async {
    await pumpHost(tester);
    await start(tester);

    expect(find.text('1.'), findsOneWidget);
    expect(find.text('O nome da página'), findsOneWidget);
    expect(find.text('Toque aqui para abrir o menu.'), findsOneWidget);
    expect(find.text('1 de 3'), findsOneWidget);
    expect(find.text('Próximo'), findsOneWidget);
    expect(find.text('Pular'), findsOneWidget);
  });

  testWidgets('Próximo avança e o último passo vira "Entendi" e conclui', (tester) async {
    await pumpHost(tester);
    await start(tester);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('2 de 3'), findsOneWidget);
    expect(find.text('Lance aqui'), findsOneWidget);

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    expect(find.text('3 de 3'), findsOneWidget);
    expect(find.text('Entendi'), findsOneWidget);
    expect(find.text('Próximo'), findsNothing);

    await tester.tap(find.text('Entendi'));
    await tester.pumpAndSettle();
    expect(result, TutorialResult.done);
    expect(find.text('Sua lista'), findsNothing);
  });

  testWidgets('Pular encerra como pulado', (tester) async {
    await pumpHost(tester);
    await start(tester);

    await tester.tap(find.text('Pular'));
    await tester.pumpAndSettle();

    expect(result, TutorialResult.skipped);
  });

  testWidgets('Esc encerra como pulado', (tester) async {
    await pumpHost(tester);
    await start(tester);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();

    expect(result, TutorialResult.skipped);
  });

  testWidgets('voltar do sistema encerra como pulado', (tester) async {
    await pumpHost(tester);
    await start(tester);

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();

    expect(result, TutorialResult.skipped);
  });

  testWidgets('tocar no elemento destacado do passo guiado roda a ação e conclui', (tester) async {
    await pumpHost(tester);
    await start(tester);

    await tester.tap(find.text('Receitas'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(targetTaps, 1);
    expect(result, TutorialResult.done);
  });

  testWidgets('tocar no véu fora do recorte não faz nada', (tester) async {
    await pumpHost(tester);
    await start(tester);

    await tester.tapAt(const Offset(200, 700));
    await tester.pumpAndSettle();

    expect(result, isNull);
    expect(find.text('O nome da página'), findsOneWidget);
    expect(targetTaps, 0);
  });

  testWidgets('um passo sem ação não reage ao toque no elemento destacado', (tester) async {
    await pumpHost(tester);
    await start(tester);
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Adicionar'), warnIfMissed: false);
    await tester.pumpAndSettle();

    expect(find.text('Lance aqui'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('rola até um elemento fora da tela antes de destacá-lo', (tester) async {
    await pumpHost(tester);
    await start(tester);
    expect(farKey.currentContext!.findRenderObject()!.attached, isTrue);
    final before = (farKey.currentContext!.findRenderObject()! as RenderBox).localToGlobal(Offset.zero).dy;
    expect(before, greaterThan(800), reason: 'começa abaixo da dobra');

    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Próximo'));
    await tester.pumpAndSettle();

    final after = (farKey.currentContext!.findRenderObject()! as RenderBox).localToGlobal(Offset.zero).dy;
    expect(after, lessThan(500), reason: 'foi rolado pra dentro da tela');
    expect(find.text('Sua lista'), findsOneWidget);
  });

  testWidgets('o balão fica sempre inteiro dentro da tela: 320 px, fonte x1.3, claro e escuro', (tester) async {
    for (final mode in [ThemeMode.light, ThemeMode.dark]) {
      await pumpHost(tester, size: const Size(320, 640), textScale: 1.3, themeMode: mode);
      await start(tester);
      for (var i = 0; i < 3; i++) {
        expect(tester.takeException(), isNull);
        final rect = tester.getRect(find.byType(Material).last);
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(rect.top, greaterThanOrEqualTo(0));
        expect(rect.bottom, lessThanOrEqualTo(640));
        await tester.tap(find.byType(FilledButton).last);
        await tester.pumpAndSettle();
      }
    }
  });

  testWidgets('um elemento muito alto, sem espaço acima nem abaixo, deixa o balão no rodapé', (tester) async {
    final tall = GlobalKey();
    await pumpHost(
      tester,
      steps: [TutorialStep(target: tall, title: 'Tudo', body: 'Esta área é grande.')],
    );
    // Re-pump with a tall element occupying most of the screen.
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Column(
              children: [
                Expanded(child: SizedBox.expand(key: tall)),
                TextButton(
                  onPressed: () => showTutorial(
                    context,
                    pageName: 'X',
                    steps: [TutorialStep(target: tall, title: 'Tudo', body: 'Esta área é grande.')],
                  ),
                  child: const Text('começar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await start(tester);

    final balloon = tester.getRect(find.byType(Material).last);
    expect(balloon.bottom, lessThanOrEqualTo(800 - 12 + 0.1));
    expect(balloon.bottom, greaterThan(700), reason: 'encaixado no rodapé');
    expect(tester.takeException(), isNull);
  });

  testWidgets('um alvo que não está na tela encerra como indisponível (não conta como visto)', (tester) async {
    final missing = GlobalKey();
    await pumpHost(
      tester,
      steps: [TutorialStep(target: missing, title: 'Fantasma', body: 'Não existe.')],
    );
    await start(tester);

    expect(result, TutorialResult.unavailable);
    expect(find.text('Fantasma'), findsNothing);
  });

  testWidgets('com "reduzir movimento", o passo muda na hora, sem animação pendente', (tester) async {
    await pumpHost(tester, reduceMotion: true);
    await start(tester);

    await tester.tap(find.text('Próximo'));
    await tester.pump(); // um quadro só
    await tester.pump();

    expect(find.text('2 de 3'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('o texto do passo é anunciado ao leitor de tela', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpHost(tester);
    await start(tester);

    expect(
      find.bySemanticsLabel(RegExp(r'Tutorial de Receitas, passo 1 de 3\. O nome da página')),
      findsOneWidget,
    );
    handle.dispose();
  });
}
