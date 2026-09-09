import 'dart:developer' as developer;

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await _activateAppCheck();
  await initializeDateFormatting('pt_BR');
  runApp(const ProviderScope(child: DindinApp()));
}

/// Firebase App Check — bot/abuse attestation. `firestore.rules`' own
/// "ABUSE / OVERLOAD POSTURE" section names this as the thing that actually
/// bounds the Spark plan's daily read/write quota (rules can't rate-limit on
/// their own). Two providers, one per platform:
///
///  - Android: Play Integrity in release builds, the debug provider under
///    `kDebugMode` (prints a token that has to be registered once in
///    Firebase Console -> App Check -> Apps -> (debug tokens) for local/CI
///    builds to keep working). The app is NOT in the Play Console yet (see
///    the Forge board) — a Play Integrity token won't verify until it is —
///    but activating now means production builds are already sending
///    tokens the day the app IS published, with nothing left to ship then.
///  - Web: reCAPTCHA v3, gated on [_recaptchaV3SiteKey] actually being set.
///    It ISN'T yet: that key only exists after registering the web app in
///    Firebase Console -> App Check -> Apps, a manual console step nobody
///    has done. Activating with a placeholder would silently produce tokens
///    the console can never verify — worse than not activating at all — so
///    this logs and skips instead. Fill in the real key there once it
///    exists; no other code change is needed.
///
/// Never marked "Enforce" from here either way — that toggle is a deliberate
/// manual step in the Firebase Console (see docs/BACKEND.md), taken only
/// after confirming real traffic is sending valid tokens.
///
/// Wrapped in try/catch: App Check is defense-in-depth, not an auth/data
/// gate, so a failure here (an emulator with no Play Services, a
/// misconfigured console) must never block the app from starting.
Future<void> _activateAppCheck() async {
  const recaptchaSiteKeyPlaceholder = 'REPLACE_WITH_RECAPTCHA_V3_SITE_KEY';
  try {
    if (kIsWeb) {
      if (_recaptchaV3SiteKey == recaptchaSiteKeyPlaceholder) {
        developer.log(
          'App Check not activated on web: no reCAPTCHA v3 site key yet. '
          'Register the web app in Firebase Console -> App Check -> Apps, '
          'then set _recaptchaV3SiteKey in lib/main.dart.',
          name: 'dindin.appCheck',
        );
        return;
      }
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaV3Provider(_recaptchaV3SiteKey),
      );
    } else {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
    }
  } catch (error, stackTrace) {
    developer.log(
      'App Check activation failed',
      name: 'dindin.appCheck',
      error: error,
      stackTrace: stackTrace,
    );
  }
}

/// Placeholder — see `_activateAppCheck`'s doc comment. Not a secret (site
/// keys are public by design, meant to ship in client code), just not
/// PROVISIONED yet.
const _recaptchaV3SiteKey = 'REPLACE_WITH_RECAPTCHA_V3_SITE_KEY';
