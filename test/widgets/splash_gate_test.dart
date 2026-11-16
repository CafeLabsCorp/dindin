// Animação de abertura: roda por cima do app, some sozinha e não roda com
// "reduzir movimento".
import 'dart:ui' show AccessibilityFeatures;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/providers/theme_provider.dart';
import 'package:dindin/theme/colors.dart';
import 'package:dindin/widgets/splash_gate.dart';

void main() {
  Future<void> pumpGate(WidgetTester tester) => tester.pumpWidget(
    // Sem Directionality em volta: a animação fica acima do MaterialApp.
    const ProviderScope(child: SplashGate(child: _App())),
  );

  testWidgets('o app já está montado por baixo e a animação sai ao terminar', (tester) async {
    await pumpGate(tester);
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(AbsorbPointer), findsWidgets, reason: 'a animação cobre o app e segura os toques');

    await tester.pump(SplashGate.duration ~/ 2);
    expect(find.byType(AbsorbPointer), findsWidgets);

    await tester.pump(SplashGate.duration);
    await tester.pump();
    expect(find.text('app'), findsOneWidget);
    expect(find.byType(Stack), findsNothing, reason: 'sem a animação, só o app');
  });

  testWidgets('com "reduzir movimento" não há animação nenhuma', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue = const _NoMotion();
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpGate(tester);

    expect(find.text('app'), findsOneWidget);
    expect(find.byType(Stack), findsNothing);
  });

  Color splashBackground(WidgetTester tester) {
    final boxes = tester.widgetList<ColoredBox>(find.byType(ColoredBox)).map((b) => b.color);
    return boxes.firstWhere((c) => c == AppPalette.lightBackground || c == AppPalette.darkBackground);
  }

  Future<void> pumpThemed(WidgetTester tester, ThemeMode mode, {required Brightness system}) async {
    tester.platformDispatcher.platformBrightnessTestValue = system;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await tester.pumpWidget(const SizedBox()); // árvore nova a cada caso
    await tester.pumpWidget(
      ProviderScope(
        overrides: [themeModeProvider.overrideWith((ref) => mode)],
        child: const SplashGate(child: _App()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('o fundo segue o tema escolhido; em "Sistema", o do aparelho', (tester) async {
    await pumpThemed(tester, ThemeMode.system, system: Brightness.dark);
    expect(splashBackground(tester), AppPalette.darkBackground);

    await pumpThemed(tester, ThemeMode.system, system: Brightness.light);
    expect(splashBackground(tester), AppPalette.lightBackground);

    // A escolha manual vale mais que o aparelho, nos dois sentidos.
    await pumpThemed(tester, ThemeMode.light, system: Brightness.dark);
    expect(splashBackground(tester), AppPalette.lightBackground);

    await pumpThemed(tester, ThemeMode.dark, system: Brightness.light);
    expect(splashBackground(tester), AppPalette.darkBackground);
    await tester.pump(SplashGate.duration * 2);
  });
}

class _App extends StatelessWidget {
  const _App();
  @override
  Widget build(BuildContext context) => const Directionality(textDirection: TextDirection.ltr, child: Text('app'));
}

class _NoMotion implements AccessibilityFeatures {
  const _NoMotion();
  @override
  bool get disableAnimations => true;
  @override
  dynamic noSuchMethod(Invocation invocation) => false;
}
