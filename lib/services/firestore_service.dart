import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/allocation.dart';
import '../models/category.dart';
import '../models/db.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_source.dart';

/// CRUD for a single user's data, mirroring the Next.js API routes under
/// `src/app/api/*` — same validation rules, now enforced client-side against
/// Firestore instead of the JSON file (see `next/src/app/api/**/route.ts`).
class FirestoreService {
  final String uid;
  final FirebaseFirestore _db;

  FirestoreService({required this.uid, FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _categories =>
      _db.collection('users/$uid/categories');
  CollectionReference<Map<String, dynamic>> get _incomes =>
      _db.collection('users/$uid/incomes');
  CollectionReference<Map<String, dynamic>> get _allocations =>
      _db.collection('users/$uid/allocations');
  CollectionReference<Map<String, dynamic>> get _expenses =>
      _db.collection('users/$uid/expenses');

  Stream<List<Category>> watchCategories() {
    return _categories.orderBy('createdAt').snapshots().map(
      (s) => s.docs.map((d) => Category.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<List<Income>> watchIncomes() {
    return _incomes.orderBy('date', descending: true).snapshots().map(
      (s) => s.docs.map((d) => Income.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<List<Allocation>> watchAllocations() {
    return _allocations.snapshots().map(
      (s) => s.docs.map((d) => Allocation.fromMap(d.id, d.data())).toList(),
    );
  }

  Stream<List<Expense>> watchExpenses() {
    return _expenses.orderBy('date', descending: true).snapshots().map(
      (s) => s.docs.map((d) => Expense.fromMap(d.id, d.data())).toList(),
    );
  }

  Future<AppDb> fetchAll() async {
    final results = await Future.wait([
      _categories.get(),
      _incomes.get(),
      _allocations.get(),
      _expenses.get(),
    ]);
    return AppDb(
      categories: results[0].docs
          .map((d) => Category.fromMap(d.id, d.data()))
          .toList(),
      incomes: results[1].docs
          .map((d) => Income.fromMap(d.id, d.data()))
          .toList(),
      allocations: results[2].docs
          .map((d) => Allocation.fromMap(d.id, d.data()))
          .toList(),
      expenses: results[3].docs
          .map((d) => Expense.fromMap(d.id, d.data()))
          .toList(),
    );
  }

  Future<Category> createCategory({
    required String name,
    required bool recurring,
  }) async {
    final doc = _categories.doc();
    final category = Category(
      id: doc.id,
      name: name,
      recurring: recurring,
      createdAt: DateTime.now().toIso8601String(),
    );
    await doc.set(category.toMap());
    return category;
  }

  /// Deletes the category and cascades to allocations/expenses that
  /// reference it, matching `next/src/app/api/categories/[id]/route.ts`.
  Future<void> deleteCategory(String id) async {
    final batch = _db.batch();
    batch.delete(_categories.doc(id));
    for (final d in (await _allocations.where('categoryId', isEqualTo: id).get()).docs) {
      batch.delete(d.reference);
    }
    for (final d in (await _expenses.where('categoryId', isEqualTo: id).get()).docs) {
      batch.delete(d.reference);
    }
    await batch.commit();
  }

  Future<Income> createIncome({
    required String date,
    required double amount,
    required IncomeSource source,
    String? description,
  }) async {
    final doc = _incomes.doc();
    final income = Income(
      id: doc.id,
      date: date,
      amount: amount,
      source: source,
      description: description,
    );
    await doc.set(income.toMap());
    return income;
  }

  Future<void> deleteIncome(String id) => _incomes.doc(id).delete();

  /// The general account balance: total income minus what's been allocated
  /// to caixinhas minus expenses charged directly against the account.
  Future<double> _accountBalance() async {
    final incomes = await _incomes.get();
    final allocations = await _allocations.get();
    final accountExpenses = await _expenses.where('categoryId', isNull: true).get();

    final totalIncome = incomes.docs.fold<double>(0, (t, d) => t + (d.data()['amount'] as num).toDouble());
    final totalAllocated = allocations.docs.fold<double>(0, (t, d) => t + (d.data()['amount'] as num).toDouble());
    final totalAccountExpenses = accountExpenses.docs.fold<double>(
      0,
      (t, d) => t + (d.data()['amount'] as num).toDouble(),
    );
    return totalIncome - totalAllocated - totalAccountExpenses;
  }

  /// An allocation moves money from the pooled account balance into a
  /// caixinha — it can't push the account balance negative.
  Future<Allocation> createAllocation({
    required String categoryId,
    required double amount,
    required String date,
  }) async {
    final categorySnap = await _categories.doc(categoryId).get();
    if (!categorySnap.exists) throw StateError('category not found');

    final available = await _accountBalance();
    if (amount > available + 1e-9) {
      throw StateError('amount exceeds account balance');
    }

    final doc = _allocations.doc();
    final allocation = Allocation(
      id: doc.id,
      categoryId: categoryId,
      amount: amount,
      date: date,
    );
    await doc.set(allocation.toMap());
    return allocation;
  }

  Future<void> deleteAllocation(String id) => _allocations.doc(id).delete();

  /// Mirrors `next/src/app/api/expenses/route.ts`: an expense can't exceed
  /// the available balance — either a caixinha's (allocated minus already
  /// spent) or, when [categoryId] is null, the general account's.
  Future<Expense> createExpense({
    required String date,
    required double amount,
    String? categoryId,
    String? description,
  }) async {
    double available;
    if (categoryId == null) {
      available = await _accountBalance();
    } else {
      final categorySnap = await _categories.doc(categoryId).get();
      if (!categorySnap.exists) throw StateError('category not found');

      final allocs = await _allocations.where('categoryId', isEqualTo: categoryId).get();
      final expenses = await _expenses.where('categoryId', isEqualTo: categoryId).get();
      final allocated = allocs.docs.fold<double>(
        0,
        (total, d) => total + (d.data()['amount'] as num).toDouble(),
      );
      final spent = expenses.docs.fold<double>(
        0,
        (total, d) => total + (d.data()['amount'] as num).toDouble(),
      );
      available = allocated - spent;
    }
    if (amount > available + 1e-9) {
      throw StateError('amount exceeds available balance');
    }

    final doc = _expenses.doc();
    final expense = Expense(
      id: doc.id,
      date: date,
      amount: amount,
      categoryId: categoryId,
      description: description,
    );
    await doc.set(expense.toMap());
    return expense;
  }

  Future<void> deleteExpense(String id) => _expenses.doc(id).delete();

  /// Wipes the user's data and writes `db` in its place, preserving original
  /// ids — used by [ImportExportService] to restore a `db.json` backup.
  Future<void> replaceAll(AppDb db) async {
    for (final collection in [_categories, _incomes, _allocations, _expenses]) {
      final existing = await collection.get();
      for (var i = 0; i < existing.docs.length; i += 400) {
        final batch = _db.batch();
        for (final d in existing.docs.skip(i).take(400)) {
          batch.delete(d.reference);
        }
        await batch.commit();
      }
    }

    final writes = <(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)>[
      for (final c in db.categories) (_categories.doc(c.id), c.toMap()),
      for (final i in db.incomes) (_incomes.doc(i.id), i.toMap()),
      for (final a in db.allocations) (_allocations.doc(a.id), a.toMap()),
      for (final e in db.expenses) (_expenses.doc(e.id), e.toMap()),
    ];
    for (var i = 0; i < writes.length; i += 400) {
      final batch = _db.batch();
      for (final (ref, data) in writes.skip(i).take(400)) {
        batch.set(ref, data);
      }
      await batch.commit();
    }
  }
}
