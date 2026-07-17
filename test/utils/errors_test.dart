// Unit tests for `friendlyErrorMessage`/`isGoneError` — pure functions, no
// I/O, previously untested. Focuses on every branch, with extra attention to
// the two messages `FirestoreService.updateCategory`/`.deleteCategory` throw
// for the catDebtFree guard (see firestore_service_test.dart for the
// throwing side of that contract).
//
// `friendlyErrorMessage` takes an `AppLocalizations` instance directly
// (mirrors `categoriaLabel`-style helpers) rather than a `BuildContext`, so
// it stays testable here without pumping a widget — `AppLocalizationsPt()`
// is constructed directly, matching the app's PT-first default.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/l10n/app_localizations_pt.dart';
import 'package:dindin/utils/errors.dart';

void main() {
  final l10n = AppLocalizationsPt();

  group('friendlyErrorMessage', () {
    test('maps "settle the debt" (spend->save conversion guard) to the pt-BR debt message', () {
      final error = StateError(
        'cannot convert a caixinha with a negative balance to a savings box; '
        'settle the debt first',
      );
      expect(
        friendlyErrorMessage(l10n, error),
        'Quite a dívida dessa caixinha (saldo de volta a zero) antes de '
        'convertê-la em cofrinho ou removê-la.',
      );
    });

    test('maps "settle the debt" (delete guard) to the same pt-BR debt message', () {
      final error = StateError(
        'cannot delete a caixinha with a negative balance; settle the debt first',
      );
      expect(
        friendlyErrorMessage(l10n, error),
        'Quite a dívida dessa caixinha (saldo de volta a zero) antes de '
        'convertê-la em cofrinho ou removê-la.',
      );
    });

    test('maps "not found" to a pt-BR "no longer exists" message', () {
      expect(
        friendlyErrorMessage(l10n, StateError('category not found')),
        'Esse lançamento não existe mais.',
      );
    });

    test('maps "source and destination must differ" to a pt-BR message', () {
      expect(
        friendlyErrorMessage(l10n, StateError('source and destination must differ')),
        'Origem e destino precisam ser diferentes.',
      );
    });

    test('maps an unsupported edit (transfer leg / changing / moving) to a pt-BR "not supported" message', () {
      expect(
        friendlyErrorMessage(l10n, StateError('cannot edit a transfer leg directly; recreate the transfer')),
        'Essa alteração não é suportada — remova e lance de novo.',
      );
      expect(
        friendlyErrorMessage(l10n, StateError("changing an allocation's caixinha is not supported; delete and recreate")),
        'Essa alteração não é suportada — remova e lance de novo.',
      );
      expect(
        friendlyErrorMessage(l10n, StateError('moving an expense between caixinha and account is not supported; delete and recreate')),
        'Essa alteração não é suportada — remova e lance de novo.',
      );
    });

    test('maps "exceeds"/"overdraw" to a pt-BR "exceeds available balance" message', () {
      expect(
        friendlyErrorMessage(l10n, StateError('amount exceeds available balance')),
        'Esse valor ultrapassa o saldo disponível.',
      );
      expect(
        friendlyErrorMessage(l10n, StateError('lowering income would overdraw the account')),
        'Esse valor ultrapassa o saldo disponível.',
      );
    });

    test('maps "cannot be negative"/"must be positive" to a pt-BR "enter a valid value" message', () {
      expect(
        friendlyErrorMessage(l10n, StateError('income amount cannot be negative')),
        'Informe um valor válido.',
      );
      expect(
        friendlyErrorMessage(l10n, StateError('transfer amount must be positive')),
        'Informe um valor válido.',
      );
    });

    test('falls back to a generic pt-BR message for an unrecognized error', () {
      expect(
        friendlyErrorMessage(l10n, StateError('some new unmapped invariant broke')),
        'Não foi possível salvar. Tente novamente.',
      );
      expect(
        friendlyErrorMessage(l10n, Exception('boom')),
        'Não foi possível salvar. Tente novamente.',
      );
    });

    test('branch order: "not found" wins over a later-matching substring in the same message', () {
      // Defends the specific if/else-if ORDER in friendlyErrorMessage: a
      // message matching an earlier branch must not fall through to a later
      // one that could also match.
      expect(
        friendlyErrorMessage(l10n, StateError('allocation not found')),
        'Esse lançamento não existe mais.',
      );
    });
  });

  group('isGoneError', () {
    test('true when the error message contains "not found"', () {
      expect(isGoneError(StateError('expense not found')), isTrue);
    });

    test('false for an unrelated error', () {
      expect(isGoneError(StateError('amount exceeds available balance')), isFalse);
      expect(isGoneError(StateError('settle the debt first')), isFalse);
    });
  });
}
