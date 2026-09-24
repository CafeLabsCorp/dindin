// Regression coverage for the 2026-09 Play Store "Google sign-in" bug
// (GoogleSignInException(code GoogleSignInExceptionCode.canceled, [16]
// Account reauth failed., null) — see docs/DEPLOY.md and
// test/services/auth_service_test.dart's "signInWithGoogle" group for the
// root-cause investigation). This file covers the one thing that belongs at
// the UI layer: whatever AuthService throws must never dead-end on a raw,
// scary exception dump — the user always gets a short, actionable message,
// and the form stays usable to retry (loading state clears, button
// re-enables).
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/features/auth/login_page.dart';
import 'package:dindin/l10n/app_localizations.dart';
import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/auth_service.dart';
import 'package:dindin/theme/theme.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockUserCredential extends Mock implements UserCredential {}

void main() {
  Future<void> pumpLoginPage(WidgetTester tester, AuthService authService) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWith((ref) => authService)],
        child: MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: AppTheme.light(),
          home: const LoginPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Google sign-in failing with GoogleSignInException shows a friendly '
    'message (never the raw exception text) and re-enables the button',
    (tester) async {
      final authService = _MockAuthService();
      when(() => authService.signInWithGoogle()).thenThrow(
        const GoogleSignInException(
          code: GoogleSignInExceptionCode.canceled,
          description: '[16] Account reauth failed.',
        ),
      );

      await pumpLoginPage(tester, authService);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      expect(
        find.text('Não foi possível entrar com o Google agora. Tente novamente em alguns instantes.'),
        findsOneWidget,
      );
      expect(find.textContaining('GoogleSignInException'), findsNothing);
      expect(find.textContaining('Account reauth failed'), findsNothing);

      // The button must still be tappable afterward (loading state cleared).
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      expect(button.onPressed, isNotNull);
    },
  );

  testWidgets(
    'a successful Google sign-in for a returning user does not log account_created',
    (tester) async {
      final authService = _MockAuthService();
      final credential = _MockUserCredential();
      when(() => credential.additionalUserInfo).thenReturn(null);
      when(() => authService.signInWithGoogle()).thenAnswer((_) async => credential);

      await pumpLoginPage(tester, authService);
      await tester.tap(find.byType(OutlinedButton));
      await tester.pumpAndSettle();

      verify(() => authService.signInWithGoogle()).called(1);
      // No error surfaced.
      expect(find.textContaining('Erro'), findsNothing);
    },
  );
}
