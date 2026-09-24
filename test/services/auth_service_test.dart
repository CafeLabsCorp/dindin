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

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

class _MockUserInfo extends Mock implements UserInfo {}

void main() {
  late _MockFirebaseAuth auth;
  late _MockGoogleSignIn googleSignIn;
  late AuthService service;

  setUpAll(() {
    // Needed because `signInWithCredential` takes a non-nullable
    // `AuthCredential`, and mocktail's `any()` requires a registered
    // fallback for any non-built-in type used that way.
    registerFallbackValue(GoogleAuthProvider.credential(idToken: 'fallback-id-token'));
  });

  setUp(() {
    auth = _MockFirebaseAuth();
    googleSignIn = _MockGoogleSignIn();
    service = AuthService(auth: auth, googleSignIn: googleSignIn);
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

  group('signInWithGoogle (native platforms — see the 2026-09 Play Store login bug)', () {
    // Context: the distributed (Play Store internal-testing) build throws
    // `GoogleSignInException(code GoogleSignInExceptionCode.canceled, [16]
    // Account reauth failed., null)` from the `_googleSignIn.authenticate()`
    // call below, for every account tried, both on silent reauth and on a
    // fully interactive "choose an account" tap. Root cause (see
    // docs/DEPLOY.md / tarefas board): NOT this Dart code — the exact
    // string "Account reauth failed" does not appear anywhere in the
    // `google_sign_in_android`/`play-services-auth`/`credentials-play-services-auth`
    // bytecode resolved by this project, meaning it is produced at runtime
    // by the Google Play services module installed on-device (Credential
    // Manager's Google ID provider backend), not by anything shipped in the
    // APK. These tests don't (and can't, without a real device signed with
    // the Play App Signing key) reproduce the underlying Play services
    // failure — they instead lock in the two things that ARE this class's
    // responsibility: the exception must propagate to the caller instead of
    // being swallowed, and `initialize()` must run exactly once no matter
    // how many sign-in attempts happen.
    test('authenticates and exchanges the ID token for a Firebase credential', () async {
      when(
        () => googleSignIn.initialize(serverClientId: any(named: 'serverClientId')),
      ).thenAnswer((_) async {});
      final account = _MockGoogleSignInAccount();
      when(
        () => account.authentication,
      ).thenReturn(const GoogleSignInAuthentication(idToken: 'id-token-123'));
      when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
      final credential = _MockUserCredential();
      when(() => auth.signInWithCredential(any())).thenAnswer((_) async => credential);

      final result = await service.signInWithGoogle();

      expect(result, same(credential));
      final captured =
          verify(() => auth.signInWithCredential(captureAny())).captured.single as AuthCredential;
      expect(captured.providerId, GoogleAuthProvider.PROVIDER_ID);
    });

    test('calls initialize() exactly once across repeated sign-in attempts', () async {
      when(
        () => googleSignIn.initialize(serverClientId: any(named: 'serverClientId')),
      ).thenAnswer((_) async {});
      final account = _MockGoogleSignInAccount();
      when(
        () => account.authentication,
      ).thenReturn(const GoogleSignInAuthentication(idToken: 'id-token-123'));
      when(() => googleSignIn.authenticate()).thenAnswer((_) async => account);
      when(() => auth.signInWithCredential(any())).thenAnswer((_) async => _MockUserCredential());

      await service.signInWithGoogle();
      await service.signInWithGoogle();

      verify(() => googleSignIn.initialize(serverClientId: any(named: 'serverClientId'))).called(1);
    });

    test(
      'propagates GoogleSignInException instead of swallowing it '
      '(regression guard for the live "canceled / Account reauth failed" bug: '
      'the UI must still find out sign-in failed)',
      () async {
        when(
          () => googleSignIn.initialize(serverClientId: any(named: 'serverClientId')),
        ).thenAnswer((_) async {});
        when(() => googleSignIn.authenticate()).thenThrow(
          const GoogleSignInException(
            code: GoogleSignInExceptionCode.canceled,
            description: '[16] Account reauth failed.',
          ),
        );

        await expectLater(
          service.signInWithGoogle(),
          throwsA(
            isA<GoogleSignInException>()
                .having((e) => e.code, 'code', GoogleSignInExceptionCode.canceled)
                .having((e) => e.description, 'description', '[16] Account reauth failed.'),
          ),
        );
        verifyNever(() => auth.signInWithCredential(any()));
      },
    );
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
