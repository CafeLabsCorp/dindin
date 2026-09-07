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

import '../models/expense.dart';
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
/// the cent, with any rounding remainder spread one cent at a time over the
/// FIRST installments — matches how a real card bill splits a purchase (e.g.
/// R$140,90 in 6x: 23,49 · 23,49 · 23,48 · 23,48 · 23,48 · 23,48), and
/// guarantees the slices sum to exactly [totalAmount] (no drift from summing
/// many rounded fractions).
///
/// Computed once per purchase from immutable fields, never per charge, so two
/// catch-up runs can never disagree about what a given installment costs.
/// Works in integer cents throughout — `totalAmount * 100` rounded once,
/// divided with `~/`/`%` — so there's no repeated floating-point rounding to
/// drift by a cent across many slices the way chained `round2` calls could.
List<double> installmentAmounts(double totalAmount, int installments) {
  final totalCents = (totalAmount * 100).round();
  final baseCents = totalCents ~/ installments;
  final remainderCents = totalCents % installments;
  return [
    for (var i = 0; i < installments; i++)
      (baseCents + (i < remainderCents ? 1 : 0)) / 100,
  ];
}

/// The 0-indexed occurrence's due date: [InstallmentPurchase.firstChargeDate]'s
/// day of month, [index] months later, clamped for short months (see
/// [dueDateFor]).
///
/// [InstallmentPurchase.dueDayOverride] replaces the day — but only for
/// occurrences that have NOT been billed yet. An installment already charged
/// keeps the date it was actually scheduled for, so moving the due day never
/// rewrites history, and the month sequence is untouched either way.
DateTime installmentDueDate(InstallmentPurchase purchase, int index) {
  final first = _parseIsoDate(purchase.firstChargeDate);
  final override = purchase.dueDayOverride;
  final day = (override != null && index >= purchase.chargedInstallments) ? override : first.day;
  return dueDateFor(first.year, first.month + index, day);
}

/// Which day each installment was actually charged on, keyed by 0-based
/// index — the counterpart to [installmentDueDate], which says when it was
/// *supposed* to be charged. The two differ whenever catch-up ran late,
/// since it only runs when the app is opened.
///
/// The link is the generated [Expense]: catch-up writes one per installment,
/// tagged with the purchase's id and described `"<name> (k/N)"`. That suffix
/// is what says WHICH installment — ordering by date would not, because an
/// early payment ([FirestoreService.payInstallmentPurchase]) also writes an
/// expense against the same purchase without being an installment at all.
///
/// An installment with no matching expense simply has no entry (its
/// description was edited, or a restore dropped the row); the caller falls
/// back to showing the due date alone.
Map<int, String> installmentPaidDates(
  InstallmentPurchase purchase,
  List<Expense> expenses,
) {
  final suffix = RegExp(r'\((\d+)/(\d+)\)$');
  final dates = <int, String>{};
  for (final expense in expenses) {
    if (expense.sourceId != purchase.id) continue;
    final match = suffix.firstMatch((expense.description ?? '').trim());
    if (match == null) continue;
    // The denominator has to agree, so a description that merely happens to
    // end in something like "(2/3)" is not read as an installment marker.
    if (int.parse(match.group(2)!) != purchase.installments) continue;
    final ordinal = int.parse(match.group(1)!);
    if (ordinal < 1 || ordinal > purchase.installments) continue;
    dates[ordinal - 1] = expense.date;
  }
  return dates;
}

/// Tolerance for "this debt is paid off", in the same spirit as
/// `FirestoreService._eps`: cents computed by subtraction can land a hair
/// off zero, and a purchase 0.0000001 short of settled is settled.
const _eps = 1e-9;

/// How much of [purchase] the SCHEDULED installments have billed so far —
/// the first [InstallmentPurchase.chargedInstallments] slices, summed.
double scheduledPaidAmount(InstallmentPurchase purchase) {
  final slices = installmentAmounts(purchase.totalAmount, purchase.installments);
  var total = 0.0;
  for (var i = 0; i < purchase.chargedInstallments && i < slices.length; i++) {
    total += slices[i];
  }
  return agg.round2(total);
}

/// What is still owed on [purchase]: the total, minus what the scheduled
/// installments already billed, minus anything paid ahead
/// ([InstallmentPurchase.amortizedAmount]).
///
/// This — not the installment counter — is what says whether the purchase is
/// over. Paying ahead shortens the schedule, so a purchase can owe nothing
/// while occurrences remain unbilled.
double outstandingAmount(InstallmentPurchase purchase) {
  final remaining =
      purchase.totalAmount - scheduledPaidAmount(purchase) - purchase.amortizedAmount;
  return remaining <= _eps ? 0 : agg.round2(remaining);
}

/// Whether [purchase] is fully paid — nothing left to charge, whether it got
/// there by running its course or by being settled early.
bool isSettled(InstallmentPurchase purchase) => outstandingAmount(purchase) <= _eps;

/// What occurrence [index] should actually charge, given [outstanding] still
/// owed: its scheduled slice, or whatever is left if that is less.
///
/// The clamp is what makes an early payoff end the purchase cleanly instead
/// of overcharging past the debt. With no extra payments it is a no-op — the
/// last occurrence's outstanding is exactly its slice, so this reproduces the
/// original "remainder on the final installment" behavior unchanged.
double installmentChargeAmount(
  InstallmentPurchase purchase,
  int index,
  double outstanding,
) {
  final slice = installmentAmounts(purchase.totalAmount, purchase.installments)[index];
  return slice <= outstanding ? slice : agg.round2(outstanding);
}

/// What [today]'s month already owes to recurring charges: every
/// subscription that bills this month, plus every installment falling due in
/// it that hasn't been settled.
///
/// This is the "before you spend anything, this much of the month is already
/// spoken for" figure. It counts the whole month, past due dates included —
/// the point is what the month costs, not what is left of it.
double committedThisMonth(
  List<Subscription> subscriptions,
  List<InstallmentPurchase> purchases,
  DateTime today,
) {
  final monthStart = DateTime(today.year, today.month);
  final monthEnd = DateTime(today.year, today.month + 1, 0);
  bool inThisMonth(DateTime d) => !d.isBefore(monthStart) && !d.isAfter(monthEnd);

  var total = 0.0;
  for (final s in subscriptions) {
    final due = dueDateFor(today.year, today.month, s.dueDay);
    // Skip a subscription registered after this month's due date already
    // passed — catch-up wouldn't bill it either.
    if (due.isBefore(_parseIsoDate(s.createdAt))) continue;
    total += s.amount;
  }
  for (final p in purchases) {
    var outstanding = outstandingAmount(p);
    for (var i = p.chargedInstallments; i < p.installments; i++) {
      if (outstanding <= _eps) break;
      final due = installmentDueDate(p, i);
      if (due.isAfter(monthEnd)) break;
      final amount = installmentChargeAmount(p, i, outstanding);
      if (inThisMonth(due)) total += amount;
      outstanding = agg.round2(outstanding - amount);
    }
  }
  return agg.round2(total);
}

/// Every installment index [purchase] should have charged by [today] but
/// hasn't yet — starting at [InstallmentPurchase.chargedInstallments], oldest
/// first, stopping at [InstallmentPurchase.installments] OR as soon as the
/// debt is paid off, whichever comes first (bounded, unlike a subscription's
/// open-ended catch-up).
///
/// After catch-up has run, a non-empty result means those installments did
/// NOT go through (almost always: the funding balance couldn't cover them).
List<int> pendingInstallmentIndexes(InstallmentPurchase purchase, DateTime today) {
  var outstanding = outstandingAmount(purchase);
  final indexes = <int>[];
  for (var i = purchase.chargedInstallments; i < purchase.installments; i++) {
    if (outstanding <= _eps) break; // settled early — the rest never bills
    if (installmentDueDate(purchase, i).isAfter(today)) break;
    indexes.add(i);
    outstanding = agg.round2(
      outstanding - installmentChargeAmount(purchase, i, outstanding),
    );
  }
  return indexes;
}
