/// Mirrors the shape/size bounds `firestore.rules` enforces on every ledger
/// doc (its "shape/size limits" section: `isName`, `isDesc`, `isIdRef`,
/// `isTag`, `isNonNegNumber`, `isSignedAmount`, `isIsoDate`) so a backup that
/// would eventually be REJECTED by the rules is refused HERE — before
/// `FirestoreService.replaceAll` deletes a single document — instead of
/// failing partway through the restore.
///
/// WHY THIS IS SEPARATE FROM `replaceAll`'s existing step-0 balance check:
/// `AppDb.fromJson` only validates that fields have the RIGHT TYPE (a cast
/// failure throws before any of this runs) — it never checks size or range.
/// A value that is well-typed but OUT OF BOUNDS (a 500-character description
/// hand-edited into an old backup, a category name copy-pasted from
/// somewhere absurd, a `dueDay` of 47) parses fine and passes the balance
/// check fine — the rules are the ONLY thing that would ever catch it, and by
/// the time the rules see it (step 3 of `replaceAll`, writing the new
/// ledger) steps 1-2 have already wiped the user's balance docs and old
/// ledger. This function closes that window: every bound is checked up
/// front, so a backup that would fail later is rejected before anything is
/// touched.
library;

import '../models/db.dart';

const _maxName = 120;
const _maxDesc = 280;
const _maxIdRef = 128;
const _maxTag = 40;
const _maxAmount = 1000000000.0;
const _minIsoDateLength = 10;
const _maxIsoDateLength = 32;

/// Thrown by [validateBackupShape]. A plain [StateError] wrapper so callers
/// (and `friendlyErrorMessage`) keep matching on `StateError` like every
/// other `FirestoreService` validation failure.
class BackupShapeError extends StateError {
  BackupShapeError(String message) : super('invalid backup: $message');
}

void _require(bool condition, String message) {
  if (!condition) throw BackupShapeError(message);
}

bool _isIsoDate(String v) => v.length >= _minIsoDateLength && v.length <= _maxIsoDateLength;

void _requireIsoDate(String v, String label) {
  _require(_isIsoDate(v), '$label: invalid date');
}

void _requireOptString(String? v, int maxLength, String label) {
  if (v == null) return;
  _require(v.length <= maxLength, '$label: too long');
}

/// Validates every doc [db] would write against `firestore.rules`' bounds.
/// Throws [BackupShapeError] naming the FIRST violation found; writes
/// nothing and has no side effects either way.
void validateBackupShape(AppDb db) {
  for (final c in db.categories) {
    final label = 'category "${c.id}"';
    _require(c.name.length <= _maxName, '$label: name too long');
    _requireIsoDate(c.createdAt, label);
    if (c.monthlyBudget != null) {
      _require(
        c.monthlyBudget! >= 0 && c.monthlyBudget! <= _maxAmount,
        '$label: monthlyBudget out of range',
      );
    }
    if (c.goalAmount != null) {
      _require(
        c.goalAmount! >= 0 && c.goalAmount! <= _maxAmount,
        '$label: goalAmount out of range',
      );
    }
  }

  for (final i in db.incomes) {
    final label = 'income "${i.id}"';
    _requireIsoDate(i.date, label);
    _require(i.amount >= 0 && i.amount <= _maxAmount, '$label: amount out of range');
    _requireOptString(i.description, _maxDesc, label);
  }

  for (final a in db.allocations) {
    final label = 'allocation "${a.id}"';
    _require(a.categoryId.length <= _maxIdRef, '$label: categoryId too long');
    _requireIsoDate(a.date, label);
    _require(
      a.amount >= -_maxAmount && a.amount <= _maxAmount,
      '$label: amount out of range',
    );
    if (a.transferId == null) {
      _require(a.amount >= 0, '$label: a plain allocation cannot be negative');
    } else {
      _require(a.transferId!.length <= _maxIdRef, '$label: transferId too long');
    }
  }

  for (final e in db.expenses) {
    final label = 'expense "${e.id}"';
    _requireIsoDate(e.date, label);
    _require(e.amount >= 0 && e.amount <= _maxAmount, '$label: amount out of range');
    _requireOptString(e.categoryId, _maxIdRef, label);
    _requireOptString(e.description, _maxDesc, label);
    _requireOptString(e.sourceType, _maxTag, label);
    _requireOptString(e.sourceId, _maxIdRef, label);
    _require(
      (e.sourceType == null) == (e.sourceId == null),
      '$label: sourceType/sourceId must be both present or both absent',
    );
  }

  for (final s in db.subscriptions) {
    final label = 'subscription "${s.id}"';
    _require(s.name.length <= _maxName, '$label: name too long');
    _require(s.amount > 0 && s.amount <= _maxAmount, '$label: amount out of range');
    _require(s.dueDay >= 1 && s.dueDay <= 31, '$label: dueDay out of range');
    _requireIsoDate(s.createdAt, label);
    if (s.lastChargedDate != null) _requireIsoDate(s.lastChargedDate!, label);
    _requireOptString(s.categoryId, _maxIdRef, label);
  }

  for (final p in db.installmentPurchases) {
    final label = 'installment purchase "${p.id}"';
    _require(p.name.length <= _maxName, '$label: name too long');
    _require(p.totalAmount > 0 && p.totalAmount <= _maxAmount, '$label: totalAmount out of range');
    _require(p.installments >= 2 && p.installments <= 36, '$label: installments out of range');
    _requireIsoDate(p.purchaseDate, label);
    _requireIsoDate(p.firstChargeDate, label);
    _requireIsoDate(p.createdAt, label);
    _require(
      p.chargedInstallments >= 0 && p.chargedInstallments <= p.installments,
      '$label: chargedInstallments out of range',
    );
    _requireOptString(p.categoryId, _maxIdRef, label);
    _require(
      p.amortizedAmount >= 0 && p.amortizedAmount <= p.totalAmount,
      '$label: amortizedAmount out of range',
    );
    if (p.dueDayOverride != null) {
      _require(
        p.dueDayOverride! >= 1 && p.dueDayOverride! <= 31,
        '$label: dueDayOverride out of range',
      );
    }
  }
}
