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

/// Runs both recurring-charge catch-ups (subscriptions, then installment
/// purchases) once per signed-in session (re-runs only if
/// [firestoreServiceProvider] itself changes, i.e. on sign-in/out) — watched
/// from [AppShell] so it fires as soon as the user lands on any authenticated
/// screen, not just Gastos. A failure here (e.g. a transient Firestore error)
/// is swallowed: catch-up is a best-effort convenience, never something that
/// should block the app from loading.
final recurringChargesCatchUpProvider = FutureProvider<void>((ref) async {
  final firestore = ref.watch(firestoreServiceProvider);
  if (firestore == null) return;
  try {
    await firestore.catchUpSubscriptions();
    await firestore.catchUpInstallmentPurchases();
  } catch (_) {
    // Best-effort: the next app open (or manual gasto entry) isn't blocked.
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
