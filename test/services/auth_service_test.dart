// Regression tests for the email-verification behavior added to close the
// 2026-09-22 security audit finding ("Verificação de e-mail não
// implementada"). Scope (ratified by Felipe): non-blocking — nothing in the
// app gates on `emailVerified`, this only covers (a) firing the
// confirmation e-mail on email/password signup, never on Google sign-in,
// (b) the "does this account need the Ajustes -> Privacidade warning" rule,
// and (c) resending, including Firebase Auth's own rate-limit error.
//
// Approach: `AuthService` takes an injectable `FirebaseAuth` (see its
// constructor) — these tests run against `mocktail` mocks of
// `FirebaseAuth`/`User`/`UserCredential`/`UserInfo` instead of a real
// Firebase project, same "inject the SDK dependency" shape
// `firestore_service_test.dart` uses with `FakeFirebaseFirestore`.
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/services/auth_service.dart';

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

void main() {
  late _MockFirebaseAuth auth;
  late AuthService service;

  setUp(() {
    auth = _MockFirebaseAuth();
    service = AuthService(auth: auth, googleSignIn: _MockGoogleSignIn());
  });

  _MockUserInfo providerInfo(String providerId) {
    final info = _MockUserInfo();
    when(() => info.providerId).thenReturn(providerId);
    return info;
  }

  group('registerWithEmail — auto-sends the confirmation e-mail (email/password signup only)', () {
    test('creates the account and sends the verification e-mail to the new user', () async {
      final newUser = _MockUser();
      when(() => newUser.sendEmailVerification()).thenAnswer((_) async {});
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(newUser);
      when(
        () => auth.createUserWithEmailAndPassword(email: 'ana@example.com', password: 'senha123'),
      ).thenAnswer((_) async => credential);

      final result = await service.registerWithEmail('ana@example.com', 'senha123');

      expect(result, same(credential));
      verify(() => newUser.sendEmailVerification()).called(1);
    });

    test('signup still succeeds even if sending the verification e-mail fails', () async {
      final newUser = _MockUser();
      when(() => newUser.sendEmailVerification()).thenThrow(
        FirebaseAuthException(code: 'network-request-failed'),
      );
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(newUser);
      when(
        () => auth.createUserWithEmailAndPassword(email: any(named: 'email'), password: any(named: 'password')),
      ).thenAnswer((_) async => credential);

      // Must not throw — a signup shouldn't fail over a best-effort e-mail.
      final result = await service.registerWithEmail('ana@example.com', 'senha123');
      expect(result, same(credential));
    });

    test('signInWithEmail (an existing account signing back in) never sends a verification e-mail', () async {
      final existingUser = _MockUser();
      final credential = _MockUserCredential();
      when(() => credential.user).thenReturn(existingUser);
      when(
        () => auth.signInWithEmailAndPassword(email: any(named: 'email'), password: any(named: 'password')),
      ).thenAnswer((_) async => credential);

      await service.signInWithEmail('ana@example.com', 'senha123');

      verifyNever(() => existingUser.sendEmailVerification());
    });
  });

  group('needsEmailVerification — Google accounts are always excluded', () {
    test('signed out (null user) does not need verification', () {
      expect(AuthService.needsEmailVerification(null), isFalse);
    });

    test('an already-verified password account does not need verification', () {
      final user = _MockUser();
      final passwordProvider = providerInfo(EmailAuthProvider.PROVIDER_ID);
      when(() => user.emailVerified).thenReturn(true);
      when(() => user.providerData).thenReturn([passwordProvider]);

      expect(AuthService.needsEmailVerification(user), isFalse);
    });

    test('an unverified password account needs verification', () {
      final user = _MockUser();
      final passwordProvider = providerInfo(EmailAuthProvider.PROVIDER_ID);
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.providerData).thenReturn([passwordProvider]);

      expect(AuthService.needsEmailVerification(user), isTrue);
    });

    test('a Google-only account never needs verification, even if emailVerified were somehow false', () {
      final user = _MockUser();
      final googleProvider = providerInfo(GoogleAuthProvider.PROVIDER_ID);
      when(() => user.emailVerified).thenReturn(false);
      when(() => user.providerData).thenReturn([googleProvider]);

      expect(AuthService.needsEmailVerification(user), isFalse);
    });
  });

  group('reloadCurrentUser', () {
    test('reloads the signed-in user', () async {
      final user = _MockUser();
      when(() => user.reload()).thenAnswer((_) async {});
      when(() => auth.currentUser).thenReturn(user);

      await service.reloadCurrentUser();

      verify(() => user.reload()).called(1);
    });

    test('is a no-op when signed out', () async {
      when(() => auth.currentUser).thenReturn(null);

      // Must not throw.
      await service.reloadCurrentUser();
    });
  });

  group('sendEmailVerification (Ajustes -> Privacidade -> "Reenviar")', () {
    test('resends to the signed-in user', () async {
      final user = _MockUser();
      when(() => user.sendEmailVerification()).thenAnswer((_) async {});
      when(() => auth.currentUser).thenReturn(user);

      await service.sendEmailVerification();

      verify(() => user.sendEmailVerification()).called(1);
    });

    test('propagates a too-many-requests rate limit so the UI can show a friendly message', () async {
      final user = _MockUser();
      when(() => user.sendEmailVerification()).thenThrow(
        FirebaseAuthException(code: 'too-many-requests'),
      );
      when(() => auth.currentUser).thenReturn(user);

      expect(
        () => service.sendEmailVerification(),
        throwsA(isA<FirebaseAuthException>().having((e) => e.code, 'code', 'too-many-requests')),
      );
    });

    test('is a no-op when signed out', () async {
      when(() => auth.currentUser).thenReturn(null);

      await service.sendEmailVerification();
    });
  });
}
