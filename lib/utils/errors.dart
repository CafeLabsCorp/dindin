/// Maps a raw error thrown by [FirestoreService] (today, always a `StateError`
/// with an English message, or a Firestore `FirebaseException`) into a short
/// pt-BR string safe to show inline under a form — every create/edit form in
/// the app previously showed `e.toString()` verbatim (something like `Bad
/// state: amount exceeds available balance`). Flagged in `docs/DESIGN.md`
/// §5.1 as a small pre-existing rough edge worth fixing while this code is
/// being touched anyway for the edit-transaction feature.
String friendlyErrorMessage(Object error) {
  final message = error.toString();
  if (message.contains('not found')) {
    return 'Esse lançamento não existe mais.';
  }
  if (message.contains('source and destination must differ')) {
    return 'Origem e destino precisam ser diferentes.';
  }
  if (message.contains('cannot edit a transfer leg') ||
      message.contains('changing') ||
      message.contains('moving')) {
    return 'Essa alteração não é suportada — remova e lance de novo.';
  }
  if (message.contains('exceeds') || message.contains('overdraw')) {
    return 'Esse valor ultrapassa o saldo disponível.';
  }
  if (message.contains('cannot be negative') || message.contains('must be positive')) {
    return 'Informe um valor válido.';
  }
  return 'Não foi possível salvar. Tente novamente.';
}

/// Whether [error] means the underlying document is already gone — edited on
/// one device while deleted on another. `docs/DESIGN.md` §5.1 flags this as a
/// low-priority-but-cheap edge case: worth an inline banner + auto-close
/// instead of leaving the user stuck on a form for a row that no longer
/// exists, without blocking the rest of the feature on it.
bool isGoneError(Object error) => error.toString().contains('not found');
