// Regression: after anything made DindinApp rebuild (e.g. picking a language
// in Ajustes), signing out stopped sending the user back to the login screen
// and signing in again stopped leaving it — the router's auth listener had been
// registered inside build and was dropped on the first rebuild.
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/app.dart';
import 'package:dindin/features/auth/login_page.dart';
import 'package:dindin/features/dashboard/dashboard_page.dart';
import 'package:dindin/providers/locale_provider.dart';
import 'package:dindin/providers/providers.dart';

class _MockUser extends Mock implements User {}

/// The Dashboard shows a spinner forever here (no data stream), so
/// `pumpAndSettle` would never return once signed in.
Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  testWidgets('login e logout continuam redirecionando depois de o app reconstruir (troca de idioma)', (tester) async {
    final auth = StreamController<User?>();
    addTearDown(auth.close);
    final user = _MockUser();
    when(() => user.emailVerified).thenReturn(true);
    when(() => user.providerData).thenReturn(const []);

    final container = ProviderContainer(
      overrides: [
        authStateProvider.overrideWith((ref) => auth.stream),
        firestoreServiceProvider.overrideWithValue(null),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const DindinApp()));
    auth.add(null);
    await tester.pumpAndSettle();
    expect(find.byType(LoginPage), findsOneWidget);

    // Something rebuilds DindinApp: the language switch in Ajustes.
    container.read(localeProvider.notifier).state = const Locale('en');
    await tester.pumpAndSettle();

    auth.add(user);
    await settle(tester);
    expect(find.byType(LoginPage), findsNothing, reason: 'entrar sai da tela de login');
    expect(find.byType(DashboardPage), findsOneWidget);

    auth.add(null);
    await settle(tester);
    expect(find.byType(LoginPage), findsOneWidget, reason: 'sair volta pro login na hora');

    auth.add(user);
    await settle(tester);
    expect(find.byType(LoginPage), findsNothing, reason: 'entrar de novo também');
  });
}
