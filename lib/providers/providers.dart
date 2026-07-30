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
  return ImportExportService(firestore);
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
final recurringChargesCatchUpProvider = FutureProvider<void>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return;
  try {
    await firestore.catchUpSubscriptions();
    await firestore.catchUpInstallmentPurchases();
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

/// Combines the 4 streams into the same summary shape as the Next.js
/// `/api/summary` route.
final summaryProvider = Provider<Summary?>((ref) {
  final categories = ref.watch(categoriesProvider).value;
  final incomes = ref.watch(incomesProvider).value;
  final allocations = ref.watch(allocationsProvider).value;
  final expenses = ref.watch(expensesProvider).value;
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
