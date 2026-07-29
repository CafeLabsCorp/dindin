/// Pure date/amount math for recurring charges (subscriptions and installment
/// purchases). No Firestore, no I/O — just "given this doc and this date,
/// which occurrences are due?".
///
/// This lives apart from `FirestoreService` because two callers need the same
/// answer and must never disagree:
///
///  - `FirestoreService.catchUpSubscriptions` /
///    `catchUpInstallmentPurchases`, which turn each due occurrence into an
///    [Expense];
///  - the Gastos screen, which shows how many occurrences are still PENDING
///    (i.e. due but not yet charged, normally because the account balance
///    couldn't cover them — see `docs/BACKEND.md`, "Assinaturas").
///
/// If the screen re-derived "pending" with its own copy of this math, the
/// badge could drift from what catch-up actually does. Same reasoning as
/// `aggregation_service.dart`, which is likewise pure and shared between the
/// UI and the services.
library;

import '../models/installment_purchase.dart';
import '../models/subscription.dart';
import 'aggregation_service.dart' as agg;

/// Clamps [day] to the last day of [year]/[month] — e.g. dueDay 31 in
/// February resolves to the 28th (or 29th on a leap year). Shared by
/// subscriptions (recurring, unbounded) and installment purchases (bounded to
/// N occurrences) — both anchor their monthly occurrence on a day of the
/// month that may not exist in every month.
DateTime dueDateFor(int year, int month, int day) {
  final lastDayOfMonth = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDayOfMonth ? lastDayOfMonth : day);
}

/// `YYYY-MM-DD`, the ISO date shape every stored date field uses.
String isoDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

DateTime _parseIsoDate(String value) => DateTime.parse(value.substring(0, 10));

/// Every due date [subscription] should have charged by [today], oldest
/// first: one per month starting the month after
/// [Subscription.lastChargedDate] (or the month it was created, if never
/// charged), skipping only a first occurrence that falls before
/// [Subscription.createdAt] — a subscription registered today must not
/// backdate a charge to before it existed.
///
/// After catch-up has run, a non-empty result means those charges did NOT go
/// through (almost always: the account balance couldn't cover them).
List<DateTime> pendingDueDates(Subscription subscription, DateTime today) {
  final created = _parseIsoDate(subscription.createdAt);
  final startMonth = subscription.lastChargedDate == null
      ? DateTime(created.year, created.month)
      : () {
          final last = _parseIsoDate(subscription.lastChargedDate!);
          return DateTime(last.year, last.month + 1);
        }();
  final dueDates = <DateTime>[];
  var cursor = startMonth;
  while (!cursor.isAfter(DateTime(today.year, today.month))) {
    final due = dueDateFor(cursor.year, cursor.month, subscription.dueDay);
    if (!due.isAfter(today) && !due.isBefore(created)) {
      dueDates.add(due);
    }
    cursor = DateTime(cursor.year, cursor.month + 1);
  }
  return dueDates;
}

/// Splits [totalAmount] into [installments] equal monthly slices, rounded to
/// the cent, with any rounding remainder absorbed into the LAST installment —
/// matches how a real card bill splits a purchase, and guarantees the slices
/// sum to exactly [totalAmount] (no drift from summing many rounded
/// fractions, same `round2` discipline as `aggregation_service.dart`).
///
/// Computed once per purchase from immutable fields, never per charge, so two
/// catch-up runs can never disagree about what a given installment costs.
List<double> installmentAmounts(double totalAmount, int installments) {
  final each = agg.round2(totalAmount / installments);
  final amounts = List<double>.filled(installments, each);
  final allButLast = agg.round2(each * (installments - 1));
  amounts[installments - 1] = agg.round2(totalAmount - allButLast);
  return amounts;
}

/// The 0-indexed occurrence's due date: [InstallmentPurchase.firstChargeDate]'s
/// day of month, [index] months later, clamped for short months (see
/// [dueDateFor]).
DateTime installmentDueDate(InstallmentPurchase purchase, int index) {
  final first = _parseIsoDate(purchase.firstChargeDate);
  return dueDateFor(first.year, first.month + index, first.day);
}

/// Every installment index [purchase] should have charged by [today] but
/// hasn't yet — starting at [InstallmentPurchase.chargedInstallments], oldest
/// first, stopping at [InstallmentPurchase.installments] (bounded, unlike a
/// subscription's open-ended catch-up).
///
/// After catch-up has run, a non-empty result means those installments did
/// NOT go through (almost always: insufficient account balance).
List<int> pendingInstallmentIndexes(InstallmentPurchase purchase, DateTime today) {
  final indexes = <int>[];
  for (var i = purchase.chargedInstallments; i < purchase.installments; i++) {
    if (installmentDueDate(purchase, i).isAfter(today)) break;
    indexes.add(i);
  }
  return indexes;
}
