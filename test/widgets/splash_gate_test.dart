// Animação de abertura: roda por cima do app, some sozinha e não roda com
// "reduzir movimento".
import 'dart:ui' show AccessibilityFeatures;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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
