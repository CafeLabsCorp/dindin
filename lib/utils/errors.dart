import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import '../l10n/app_localizations.dart';

/// Maps a raw error thrown by [FirestoreService] (today, always a `StateError`
/// with an English message, or a Firestore `FirebaseException`) into a short,
/// localized string safe to show inline under a form — every create/edit form
/// in the app previously showed `e.toString()` verbatim (something like `Bad
/// state: amount exceeds available balance`). Flagged in `docs/DESIGN.md`
/// §5.1 as a small pre-existing rough edge worth fixing while this code is
/// being touched anyway for the edit-transaction feature.
///
/// Takes [l10n] directly (not a `BuildContext`) so it stays callable from
/// plain unit tests — mirrors `categoriaLabel`-style helpers, see the i18n
/// pass that added it.
String friendlyErrorMessage(AppLocalizations l10n, Object error) {
  final message = error.toString();
  if (message.contains('not found')) {
    return l10n.errorNotFound;
  }
  if (message.contains('source and destination must differ')) {
    return l10n.originDestinationMustDifferError;
  }
  if (message.contains('cannot edit a transfer leg') ||
      message.contains('changing') ||
      message.contains('moving')) {
    return l10n.errorUnsupportedEdit;
  }
  if (message.contains('settle the debt')) {
    return l10n.errorSettleDebt;
  }
  if (message.contains('exceeds') || message.contains('overdraw')) {
    return l10n.errorExceedsBalance;
  }
  if (message.contains('cannot be negative') || message.contains('must be positive')) {
    return l10n.invalidAmountError;
  }
  // An unrecognized Firebase failure (rules denial, quota, network...) keeps
  // its short code on screen: the generic text alone made one user's failed
  // save impossible to diagnose from a screenshot.
  if (error is FirebaseException && error.code.isNotEmpty) {
    return l10n.errorGenericSaveCode(error.code);
  }
  return l10n.errorGenericSave;
}

/// Whether [error] means the underlying document is already gone — edited on
/// one device while deleted on another. `docs/DESIGN.md` §5.1 flags this as a
/// low-priority-but-cheap edge case: worth an inline banner + auto-close
/// instead of leaving the user stuck on a form for a row that no longer
/// exists, without blocking the rest of the feature on it.
bool isGoneError(Object error) => error.toString().contains('not found');

/// Maps a Firebase Auth failure on the login/register form to a localized
/// sentence. Auth used to pass `e.message` straight to the screen, so an
/// otherwise Portuguese app showed things like "The supplied auth credential
/// is incorrect, malformed or has expired."
///
/// Wrong e-mail and wrong password deliberately share one message
/// (`invalid-credential` and its older aliases): telling them apart would let
/// anyone probe which e-mails have an account.
String friendlyAuthErrorMessage(AppLocalizations l10n, FirebaseAuthException error) {
  return switch (error.code) {
    'invalid-credential' ||
    'invalid-login-credentials' ||
    'wrong-password' ||
    'user-not-found' => l10n.authInvalidCredentialError,
    'email-already-in-use' => l10n.authEmailInUseError,
    'invalid-email' => l10n.authInvalidEmailError,
    'weak-password' => l10n.authWeakPasswordError,
    'too-many-requests' => l10n.authTooManyRequestsError,
    'network-request-failed' => l10n.authNetworkError,
    'user-disabled' => l10n.authUserDisabledError,
    _ => l10n.authGenericError,
  };
}
