import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/allocation.dart';
import '../models/category.dart';
import '../models/db.dart';
import '../models/expense.dart';
import '../models/income.dart';
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

/// Unallocated amount per income id, derived the same way as the Next.js
/// `/api/incomes` route (`unallocatedByIncome` in `aggregations.ts`).
final unallocatedByIncomeProvider = Provider<Map<String, double>>((ref) {
  final incomes = ref.watch(incomesProvider).value ?? [];
  final allocations = ref.watch(allocationsProvider).value ?? [];
  final db = AppDb(
    categories: const [],
    incomes: incomes,
    allocations: allocations,
    expenses: const [],
  );
  return unallocatedByIncome(db);
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
