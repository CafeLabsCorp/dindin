import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_sign_in/google_sign_in.dart';

/// Auto-created "Web client" OAuth id for the dindin-cafelabs Firebase
/// project's Google sign-in provider (Firebase Console → Authentication →
/// Sign-in method → Google). Used as `serverClientId` so the Android sign-in
/// flow's id token audience is accepted by Firebase Auth.
const _googleServerClientId = '368601445760-3b72pd88q72jq8bp3eja9dpe85guphc8.apps.googleusercontent.com';

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  bool _googleInitialized = false;

  AuthService({FirebaseAuth? auth, GoogleSignIn? googleSignIn})
    : _auth = auth ?? FirebaseAuth.instance,
      _googleSignIn = googleSignIn ?? GoogleSignIn.instance {
    // Explicit, since a browser tab getting recreated (not just reloaded)
    // has occasionally been reported to lose the session without this on
    // some Firebase Auth JS SDK versions. Web-only API.
    if (kIsWeb) {
      _auth.setPersistence(Persistence.LOCAL);
    }
  }

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  /// Security audit finding "Verificação de e-mail não implementada"
  /// (2026-09-22), scope ratified by Felipe: non-blocking — nothing in the
  /// app gates on `emailVerified` (solo-use finance app, no
  /// invite/sharing), this only gets the confirmation e-mail sent.
  ///
  /// Sending is best-effort: a fresh signup must not fail just because the
  /// verification e-mail couldn't go out right this second (e.g. a
  /// transient network blip immediately after the account was created) —
  /// the unverified state stays visible and retryable from Ajustes ->
  /// Privacidade afterward (see [needsEmailVerification] /
  /// [sendEmailVerification]).
  Future<UserCredential> registerWithEmail(String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    try {
      await credential.user?.sendEmailVerification();
    } catch (error, stackTrace) {
      developer.log(
        'failed to send verification email after signup',
        name: 'dindin.auth',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return credential;
  }

  /// Whether [user] is a password (email/senha) account that hasn't
  /// confirmed its e-mail yet — the condition the Ajustes -> Privacidade
  /// warning and resend button key off of.
  ///
  /// Deliberately excludes Google accounts: `providerData` is checked
  /// (rather than trusting `emailVerified` alone) because a Google sign-in
  /// is already verified upstream by Google — asking that person to
  /// "confirm" an e-mail they never set a password for would be
  /// nonsensical, and [sendEmailVerification] below would have nothing
  /// useful to do for them either.
  static bool needsEmailVerification(User? user) {
    if (user == null || user.emailVerified) return false;
    return user.providerData.any((info) => info.providerId == EmailAuthProvider.PROVIDER_ID);
  }

  /// Re-fetches the signed-in user's data from Firebase Auth so
  /// `emailVerified` picks up a confirmation that happened outside this app
  /// session (e.g. the link was tapped in a mail client). `User.emailVerified`
  /// is a snapshot taken at sign-in/token-refresh time and does NOT update on
  /// its own — callers reload at the moments that matter (opening Ajustes,
  /// the app resuming from the background) rather than polling. A no-op if
  /// signed out.
  Future<void> reloadCurrentUser() async {
    await _auth.currentUser?.reload();
  }

  /// Resends the confirmation e-mail to the signed-in user (Ajustes ->
  /// Privacidade -> "Reenviar e-mail de verificação"). A no-op if signed
  /// out. Firebase Auth itself rate-limits this — throws
  /// `FirebaseAuthException(code: 'too-many-requests')` after a few calls in
  /// a short window; the caller (`SettingsPage`) turns that into a friendly
  /// message instead of an unhandled exception.
  Future<void> sendEmailVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// On Web, delegates entirely to Firebase Auth's own popup flow — it uses
  /// the project's Firebase "authorized domains" (which already includes
  /// `localhost`), so no Google Cloud OAuth client / JavaScript origin setup
  /// is needed. On native platforms, uses the `google_sign_in` package,
  /// which instead relies on the Android app's SHA-1 fingerprint being
  /// registered with the Firebase project.
  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      return _auth.signInWithPopup(GoogleAuthProvider());
    }

    if (!_googleInitialized) {
      _googleInitialized = true;
      await _googleSignIn.initialize(serverClientId: _googleServerClientId);
    }
    final account = await _googleSignIn.authenticate();
    final credential = GoogleAuthProvider.credential(idToken: account.authentication.idToken);
    return _auth.signInWithCredential(credential);
  }

  Future<void> signOut() async {
    if (!kIsWeb) {
      await _googleSignIn.signOut();
    }
    await _auth.signOut();
  }

  /// Hard-deletes the signed-in Firebase Auth account (decision 3, ratified
  /// 2026-08-31: option A, immediate, no carência/recovery). Callers MUST
  /// call `FirestoreService.deleteAllUserData()` first — this only removes
  /// the Auth identity, not `users/{uid}` in Firestore, and doing it in the
  /// other order would strand the Firestore data unreachable forever (uids
  /// are never reissued — see `scripts/sweep_orphans.mjs`, the server-side
  /// safety net for exactly that failure mode).
  ///
  /// Can throw `FirebaseAuthException(code: 'requires-recent-login')` — Auth
  /// account deletion requires a RECENT sign-in; the caller (see
  /// `SettingsPage`) shows a message asking the user to sign out and back in
  /// before retrying, rather than dead-ending on a generic error. A no-op if
  /// already signed out.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (!kIsWeb) {
      // Best-effort: forgets the cached Google session so a future sign-in
      // attempt on this device doesn't silently reuse credentials for an
      // account that no longer exists.
      try {
        await _googleSignIn.signOut();
      } catch (_) {
        // Not fatal to account deletion either way.
      }
    }
    await user.delete();
  }
}
