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

  Future<UserCredential> registerWithEmail(String email, String password) {
    return _auth.createUserWithEmailAndPassword(email: email, password: password);
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
}
