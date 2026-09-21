import 'dart:developer' as developer;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/allocation.dart';
import '../models/category.dart';
import '../models/db.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/installment_purchase.dart';
import '../models/subscription.dart';
import '../services/aggregation_service.dart';
import '../services/analytics_service.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/import_export_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authServiceProvider).authStateChanges;
});

/// Null while signed out — screens under the auth guard never see a null
/// [FirestoreService], see `lib/app.dart`.
final firestoreServiceProvider = Provider<FirestoreService?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return null;
  return FirestoreService(uid: user.uid);
});

final importExportServiceProvider = Provider<ImportExportService?>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return null;
  return ImportExportService(firestore, analytics: ref.watch(analyticsServiceProvider));
});

/// Wraps `FirebaseAnalytics.instance` — see its own doc comment for the
/// exact event/opt-out contract (decision 7, docs/BACKEND.md). Unlike the
/// other services here it does NOT depend on [firestoreServiceProvider]: it
/// has to exist (and, in particular, `setEnabled` has to be callable) even
/// while signed out, since the opt-out preference itself lives per-account
/// in Firestore and is applied via [analyticsOptOutProvider]'s listener in
/// `AppShell`, not here.
final analyticsServiceProvider = Provider<AnalyticsService>((ref) => AnalyticsService());

/// The Analytics opt-out toggle (Ajustes -> Privacidade), streamed from the
/// signed-in user's `meta/settings` doc. `.value` is `null` while signed out
/// (same `Stream.empty()` convention as [categoriesProvider] and friends,
/// deliberately — it keeps every consumer's `?? false` fallback the single
/// place that decides the signed-out/not-yet-loaded default, instead of
/// this provider ALSO resolving to a concrete value that would make
/// `AppShell` try to touch the real `FirebaseAnalytics.instance` even before
/// anyone is signed in). Before the doc has ever been written for a
/// signed-in user, see `FirestoreService.watchAnalyticsOptOut` — that
/// defaults to `false` (collection ON).
final analyticsOptOutProvider = StreamProvider<bool>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchAnalyticsOptOut();
});

final categoriesProvider = StreamProvider<List<Category>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchCategories();
});

final incomesProvider = StreamProvider<List<Income>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchIncomes();
});

final allocationsProvider = StreamProvider<List<Allocation>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchAllocations();
});

final expensesProvider = StreamProvider<List<Expense>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchExpenses();
});

/// The unwindowed counterparts of [incomesProvider]/[allocationsProvider]/
/// [expensesProvider], used only by [summaryProvider] — see
/// `FirestoreService.watchAllIncomes`'s doc comment for why the Dashboard
/// total can't be computed from the `.limit()`-ed streams above.
final allIncomesProvider = StreamProvider<List<Income>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchAllIncomes();
});

final allAllocationsProvider = StreamProvider<List<Allocation>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchAllAllocations();
});

final allExpensesProvider = StreamProvider<List<Expense>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchAllExpenses();
});

final subscriptionsProvider = StreamProvider<List<Subscription>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchSubscriptions();
});

final installmentPurchasesProvider = StreamProvider<List<InstallmentPurchase>>((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const Stream.empty();
  return firestore.watchInstallmentPurchases();
});

/// Today's date as the UI sees it.
///
/// A provider rather than a bare `DateTime.now()` inside `build` because how
/// many charges count as "pending" is a function of the current date — a
/// widget test reading the wall clock would quietly change meaning as time
/// passes. Mirrors the injectable `clock` on [FirestoreService], which exists
/// for the same reason on the writing side.
final todayProvider = Provider<DateTime>((ref) => DateTime.now());

/// Runs both recurring-charge catch-ups (subscriptions, then installment
/// purchases) once per signed-in session (re-runs only if
/// [firestoreServiceProvider] itself changes, i.e. on sign-in/out) — watched
/// from [AppShell] so it fires as soon as the user lands on any authenticated
/// screen, not just Gastos.
///
/// A failure is logged and left on the provider as an [AsyncError] instead of
/// being swallowed. It still can't block the app: `ref.watch` on a
/// [FutureProvider] hands back an [AsyncValue] rather than throwing, and
/// [AppShell] watches this purely for the side effect and ignores the value.
/// What surfacing it buys is on the Gastos screen, which needs to tell two
/// states apart that used to look identical:
///
///  - finished fine, and the charges still listed as pending genuinely didn't
///    fit the account balance (actionable: add money);
///  - never finished, so "pending" says nothing yet (not actionable, and
///    blaming the balance there would be a lie).
final recurringChargesCatchUpProvider = FutureProvider<RecurringChargeReport>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return const RecurringChargeReport();
  try {
    final subscriptions = await firestore.catchUpSubscriptions();
    final installments = await firestore.catchUpInstallmentPurchases();
    // What this app open cost the user, for the screen to actually say so —
    // these charges are posted without any interaction, so nothing else would.
    return subscriptions + installments;
  } catch (error, stackTrace) {
    developer.log(
      'recurring charge catch-up failed',
      name: 'dindin.recurringCharges',
      error: error,
      stackTrace: stackTrace,
    );
    rethrow;
  }
});

/// Combines the full, unwindowed ledger into the same summary shape as the
/// Next.js `/api/summary` route.
///
/// Deliberately does NOT read [incomesProvider]/[allocationsProvider]/
/// [expensesProvider] — those are `.limit()`-ed for the Receitas/Gastos/
/// Parcelamentos list screens (see `FirestoreService`'s `_ledgerLimit` doc
/// comment, "read windowing") and summing them here would silently
/// undercount `total`/`accountBalance`/`balancesByCategory` for any account
/// whose history exceeds that cap. The Dashboard balance is a money-trust
/// number, so it reads [allIncomesProvider]/[allAllocationsProvider]/
/// [allExpensesProvider] instead, at the cost of more reads on accounts with
/// a lot of history — a deliberate trade-off for a production financial app
/// (see docs/BACKEND.md, "read windowing").
final summaryProvider = Provider<Summary?>((ref) {
  final categories = ref.watch(categoriesProvider).value;
  final incomes = ref.watch(allIncomesProvider).value;
  final allocations = ref.watch(allAllocationsProvider).value;
  final expenses = ref.watch(allExpensesProvider).value;
  if (categories == null || incomes == null || allocations == null || expenses == null) {
    return null;
  }
  final db = AppDb(
    categories: categories,
    incomes: incomes,
    allocations: allocations,
    expenses: expenses,
  );
  return buildSummary(db);
});
