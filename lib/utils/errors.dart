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
  return l10n.errorGenericSave;
}

/// Whether [error] means the underlying document is already gone — edited on
/// one device while deleted on another. `docs/DESIGN.md` §5.1 flags this as a
/// low-priority-but-cheap edge case: worth an inline banner + auto-close
/// instead of leaving the user stuck on a form for a row that no longer
/// exists, without blocking the rest of the feature on it.
bool isGoneError(Object error) => error.toString().contains('not found');
