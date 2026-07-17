import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/allocation.dart';
import '../models/category.dart';
import '../models/db.dart';
import '../models/expense.dart';
import '../models/income.dart';
import '../models/income_source.dart';
import 'aggregation_service.dart' as agg;

/// CRUD for a single user's data, mirroring the Next.js API routes under
/// `src/app/api/*` — same validation rules, now enforced client-side against
/// Firestore instead of the JSON file (see `next/src/app/api/**/route.ts`).
///
/// MONEY INTEGRITY (Option B — free Spark tier, no Cloud Functions). The
/// running balances are DENORMALIZED into O(1) documents:
///   * `users/{uid}/meta/account`     `{ balance }` — general account balance
///   * `users/{uid}/balances/{catId}` `{ balance }` — one per caixinha
/// Every mutating write that affects a balance runs inside a Firestore
/// TRANSACTION that updates the ledger doc AND the affected balance doc(s)
/// together, so the two never drift under normal operation. `firestore.rules`
/// (Phase 2) then re-validates each write with getAfter(): the balance doc(s)
/// must move by exactly the ledger delta and never go negative. See
/// docs/BACKEND.md.
///
/// The balance docs are a DERIVED cache: they are NOT part of the JSON backup
/// (which stays the four ledger collections only) and are rebuilt from the
/// ledger by the one-time backfill script and by [replaceAll] on restore. The
/// app's on-screen balances are still summed from the ledger by
/// `aggregation_service`, so a cache that ever drifts never misleads the user.
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
  CollectionReference<Map<String, dynamic>> get _balances =>
      _db.collection('users/$uid/balances');

  /// The general account balance doc.
  DocumentReference<Map<String, dynamic>> get _account =>
      _db.doc('users/$uid/meta/account');

  /// A single caixinha's balance doc, keyed by the category id.
  DocumentReference<Map<String, dynamic>> _balance(String categoryId) =>
      _balances.doc(categoryId);

  /// Reads a balance doc inside a transaction, treating a missing doc as 0.
  Future<double> _readBalance(
    Transaction tx,
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final snap = await tx.get(ref);
    final data = snap.data();
    if (data == null) return 0;
    return (data['balance'] as num).toDouble();
  }

  /// Reads a balance doc OUTSIDE a transaction, treating a missing doc as 0.
  /// Used by the metadata-only pre-write guards (spend->save conversion), which
  /// don't run in a transaction because they never mutate a balance.
  Future<double> _readBalanceOnce(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    final data = (await ref.get()).data();
    if (data == null) return 0;
    return (data['balance'] as num).toDouble();
  }

  static const _eps = 1e-9;

  /// Mirrors `catDeltaOk` in `firestore.rules`: a write to a caixinha's
  /// balance doc is fine if the result stays non-negative, OR the write
  /// doesn't deepen an existing debt (settling it back up, even partially),
  /// OR the caixinha is currently configured to allow a negative balance.
  /// [before]/[after] are the balance doc's value before/after this write.
  /// Kept in lockstep with the deployed rules so the client never blocks a
  /// write the server would accept, nor optimistically allows one the server
  /// will reject with a raw permission error.
  bool _catDeltaOk(Category category, double before, double after) {
    final delta = after - before;
    return after >= -_eps || delta >= -_eps || category.allowsNegativeBalance;
  }

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

  // -------------------------------------------------------------------------
  // Categories. A caixinha's balance doc is created alongside the category
  // (at 0) and torn down with it, so ledger writes can always reach it.
  // -------------------------------------------------------------------------
  Future<Category> createCategory({
    required String name,
    required bool recurring,
    double? monthlyBudget,
    CategoryKind? kind,
    double? goalAmount,
    bool? allowNegative,
  }) async {
    final doc = _categories.doc();
    final category = Category(
      id: doc.id,
      name: name,
      recurring: recurring,
      createdAt: DateTime.now().toIso8601String(),
      monthlyBudget: monthlyBudget,
      kind: kind,
      goalAmount: goalAmount,
      allowNegative: allowNegative,
    );
    final batch = _db.batch();
    batch.set(doc, category.toMap());
    batch.set(_balance(doc.id), {'balance': 0.0});
    await batch.commit();
    return category;
  }

  /// Edits a category's editable fields. `createdAt` and `id` are immutable.
  /// Pass [clearMonthlyBudget] to remove an existing budget (setting
  /// [monthlyBudget] to null alone is treated as "leave unchanged"). Metadata
  /// only — never touches the caixinha balance.
  ///
  /// [allowNegative] doesn't need a `clearAllowNegative` sibling like the
  /// amount fields: it's a boolean toggle, so the UI always sends an explicit
  /// `true`/`false` when the user's choice applies (including `false` when
  /// [kind] is being set/kept to [CategoryKind.save], where the toggle is
  /// meaningless — see [Category.allowsNegativeBalance]); `null` here only
  /// ever means "this call isn't touching it, keep the current value".
  Future<void> updateCategory(
    String id, {
    String? name,
    bool? recurring,
    double? monthlyBudget,
    bool clearMonthlyBudget = false,
    CategoryKind? kind,
    double? goalAmount,
    bool clearGoalAmount = false,
    bool? allowNegative,
  }) async {
    final snap = await _categories.doc(id).get();
    if (!snap.exists) throw StateError('category not found');
    final current = Category.fromMap(id, snap.data()!);
    final updated = Category(
      id: id,
      name: name ?? current.name,
      recurring: recurring ?? current.recurring,
      createdAt: current.createdAt,
      monthlyBudget:
          clearMonthlyBudget ? null : (monthlyBudget ?? current.monthlyBudget),
      kind: kind ?? current.kind,
      goalAmount: clearGoalAmount ? null : (goalAmount ?? current.goalAmount),
      allowNegative: allowNegative ?? current.allowNegative,
    );
    // Guard (mirrors `catDebtFree` + `convertsSpendToSave` in firestore.rules):
    // converting a spend envelope that currently holds a debt into a 'save' box
    // would strand that debt — a 'save' caixinha may never be negative, and
    // restore/backfill treat "save with a negative balance" as corruption. Block
    // it until the debt is settled to >= 0. Only reads the balance doc when the
    // conversion is actually happening, so ordinary edits pay no extra read. The
    // server rule is the non-bypassable guarantee; this just surfaces it early.
    if (current.effectiveKind == CategoryKind.spend &&
        updated.effectiveKind == CategoryKind.save) {
      final balance = await _readBalanceOnce(_balance(id));
      if (balance < -_eps) {
        throw StateError(
          'cannot convert a caixinha with a negative balance to a savings box; '
          'settle the debt first',
        );
      }
    }
    await _categories.doc(id).set(updated.toMap());
  }

  /// Deletes the category and cascades to allocations/expenses that reference
  /// it (matching `next/src/app/api/categories/[id]/route.ts`), removes the
  /// caixinha's balance doc, and restores the account balance by the sum of
  /// the (plain) allocations that had drawn from it. Removing the balance doc
  /// is what lets the cascaded ledger deletes fall through the rules'
  /// teardown path.
  ///
  /// NOTE: a category holding transfer legs is not fully supported here (the
  /// paired leg in another caixinha would be orphaned). Transfers are not
  /// reachable from the UI yet; see docs/BACKEND.md.
  Future<void> deleteCategory(String id) async {
    final allocs = await _allocations.where('categoryId', isEqualTo: id).get();
    final exps = await _expenses.where('categoryId', isEqualTo: id).get();

    // Sum only PLAIN allocations for the account reversal; transfer legs net to
    // zero against the account.
    double allocSum = 0;
    for (final d in allocs.docs) {
      if (d.data()['transferId'] == null) {
        allocSum += (d.data()['amount'] as num).toDouble();
      }
    }

    await _db.runTransaction((tx) async {
      // Guard (mirrors `catDebtFree` on the categories delete rule): deleting a
      // caixinha while it holds a debt (negative balance) would destroy that
      // debt and break money conservation — the debt must be paid back to >= 0
      // first. Read inside the transaction so the check and the cascade commit
      // atomically. This is the same commit the server rule inspects via the
      // pre-commit balance, so the two agree.
      final catBal = await _readBalance(tx, _balance(id));
      if (catBal < -_eps) {
        throw StateError(
          'cannot delete a caixinha with a negative balance; settle the debt '
          'first',
        );
      }
      final acct = await _readBalance(tx, _account);
      final newAcct = acct + allocSum;
      tx.delete(_categories.doc(id));
      tx.delete(_balance(id));
      for (final d in allocs.docs) {
        tx.delete(d.reference);
      }
      for (final d in exps.docs) {
        tx.delete(d.reference);
      }
      tx.set(_account, {'balance': newAcct < 0 ? 0.0 : newAcct});
    });
  }

  // -------------------------------------------------------------------------
  // Incomes. Only ever adjust the account balance.
  // -------------------------------------------------------------------------
  Future<Income> createIncome({
    required String date,
    required double amount,
    required IncomeSource source,
    String? description,
  }) async {
    if (amount < 0) throw StateError('income amount cannot be negative');
    final doc = _incomes.doc();
    final income = Income(
      id: doc.id,
      date: date,
      amount: amount,
      source: source,
      description: description,
    );
    await _db.runTransaction((tx) async {
      final acct = await _readBalance(tx, _account);
      tx.set(doc, income.toMap());
      tx.set(_account, {'balance': acct + amount});
    });
    return income;
  }

  /// Edits an income. Lowering it can't push the account balance negative.
  Future<void> updateIncome(
    String id, {
    required String date,
    required double amount,
    required IncomeSource source,
    String? description,
  }) async {
    if (amount < 0) throw StateError('income amount cannot be negative');
    final income = Income(
      id: id,
      date: date,
      amount: amount,
      source: source,
      description: description,
    );
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_incomes.doc(id));
      if (!snap.exists) throw StateError('income not found');
      final old = (snap.data()!['amount'] as num).toDouble();
      final acct = await _readBalance(tx, _account);
      final newAcct = acct - old + amount;
      if (newAcct < -_eps) {
        throw StateError('lowering income would overdraw the account');
      }
      tx.set(_incomes.doc(id), income.toMap());
      tx.set(_account, {'balance': newAcct});
    });
  }

  Future<void> deleteIncome(String id) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_incomes.doc(id));
      if (!snap.exists) return;
      final old = (snap.data()!['amount'] as num).toDouble();
      final acct = await _readBalance(tx, _account);
      final newAcct = acct - old;
      if (newAcct < -_eps) {
        throw StateError('deleting this income would overdraw the account');
      }
      tx.delete(_incomes.doc(id));
      tx.set(_account, {'balance': newAcct});
    });
  }

  // -------------------------------------------------------------------------
  // Allocations (account -> caixinha).
  // -------------------------------------------------------------------------
  Future<Allocation> createAllocation({
    required String categoryId,
    required double amount,
    required String date,
  }) async {
    if (amount < 0) throw StateError('allocation amount cannot be negative');
    final doc = _allocations.doc();
    final allocation = Allocation(
      id: doc.id,
      categoryId: categoryId,
      amount: amount,
      date: date,
    );
    await _db.runTransaction((tx) async {
      final catSnap = await tx.get(_categories.doc(categoryId));
      if (!catSnap.exists) throw StateError('category not found');
      final acct = await _readBalance(tx, _account);
      final catBal = await _readBalance(tx, _balance(categoryId));
      if (amount > acct + _eps) {
        throw StateError('amount exceeds account balance');
      }
      tx.set(doc, allocation.toMap());
      tx.set(_account, {'balance': acct - amount});
      tx.set(_balance(categoryId), {'balance': catBal + amount});
    });
    return allocation;
  }

  /// Edits a plain allocation's amount/date. The caixinha is fixed — changing
  /// it is delete + recreate. Transfer legs can't be edited individually.
  Future<void> updateAllocation(
    String id, {
    required String categoryId,
    required double amount,
    required String date,
  }) async {
    if (amount < 0) throw StateError('allocation amount cannot be negative');
    final allocation = Allocation(
      id: id,
      categoryId: categoryId,
      amount: amount,
      date: date,
    );
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_allocations.doc(id));
      if (!snap.exists) throw StateError('allocation not found');
      final data = snap.data()!;
      if (data['transferId'] != null) {
        throw StateError('cannot edit a transfer leg directly; recreate the transfer');
      }
      final oldCat = data['categoryId'] as String;
      if (categoryId != oldCat) {
        throw StateError('changing an allocation\'s caixinha is not supported; delete and recreate');
      }
      final catSnap = await tx.get(_categories.doc(categoryId));
      if (!catSnap.exists) throw StateError('category not found');
      final category = Category.fromMap(categoryId, catSnap.data()!);
      final old = (data['amount'] as num).toDouble();
      final acct = await _readBalance(tx, _account);
      final catBal = await _readBalance(tx, _balance(categoryId));
      final newAcct = acct - amount + old; // account += (old - new)
      if (newAcct < -_eps) {
        throw StateError('amount exceeds account balance');
      }
      final newCat = catBal + amount - old;
      if (!_catDeltaOk(category, catBal, newCat)) {
        throw StateError('reducing this allocation would overdraw the caixinha');
      }
      tx.set(_allocations.doc(id), allocation.toMap());
      tx.set(_account, {'balance': newAcct});
      tx.set(_balance(categoryId), {'balance': newCat});
    });
  }

  /// Deletes an allocation. If it's a transfer leg, BOTH legs are removed via
  /// [deleteTransfer] so a half-transfer can never be left behind.
  Future<void> deleteAllocation(String id) async {
    final snap = await _allocations.doc(id).get();
    if (!snap.exists) return;
    final transferId = snap.data()!['transferId'] as String?;
    if (transferId != null) {
      await deleteTransfer(transferId);
      return;
    }
    await _db.runTransaction((tx) async {
      final s = await tx.get(_allocations.doc(id));
      if (!s.exists) return;
      final data = s.data()!;
      final cat = data['categoryId'] as String;
      final amt = (data['amount'] as num).toDouble();
      // Unlike `updateAllocation`, a missing category here isn't fatal (the
      // category may have been deleted, orphaning this allocation) — fall
      // back to a category that doesn't allow negative, i.e. the pre-existing
      // strict behavior, rather than introducing a new failure mode on delete.
      final catSnap = await tx.get(_categories.doc(cat));
      final category = catSnap.exists
          ? Category.fromMap(cat, catSnap.data()!)
          : Category(id: cat, name: '', recurring: false, createdAt: '');
      final acct = await _readBalance(tx, _account);
      final catBal = await _readBalance(tx, _balance(cat));
      final newCat = catBal - amt;
      if (!_catDeltaOk(category, catBal, newCat)) {
        throw StateError('removing this allocation would overdraw the caixinha');
      }
      tx.delete(_allocations.doc(id));
      tx.set(_account, {'balance': acct + amt});
      tx.set(_balance(cat), {'balance': newCat});
    });
  }

  /// Moves [amount] from one caixinha to another as a pair of allocation legs
  /// sharing a generated `transferId` (a negative leg on the source, a positive
  /// leg on the destination). The account balance is untouched. Returns the
  /// shared `transferId`.
  Future<String> createTransfer({
    required String fromCategoryId,
    required String toCategoryId,
    required double amount,
    required String date,
  }) async {
    if (amount <= 0) throw StateError('transfer amount must be positive');
    if (fromCategoryId == toCategoryId) {
      throw StateError('source and destination must differ');
    }
    final transferId = _allocations.doc().id;
    final fromLeg = _allocations.doc();
    final toLeg = _allocations.doc();
    await _db.runTransaction((tx) async {
      final fromSnap = await tx.get(_categories.doc(fromCategoryId));
      if (!fromSnap.exists) throw StateError('source category not found');
      final fromCategory = Category.fromMap(fromCategoryId, fromSnap.data()!);
      final toSnap = await tx.get(_categories.doc(toCategoryId));
      if (!toSnap.exists) throw StateError('destination category not found');
      final fromBal = await _readBalance(tx, _balance(fromCategoryId));
      final toBal = await _readBalance(tx, _balance(toCategoryId));
      if (!_catDeltaOk(fromCategory, fromBal, fromBal - amount)) {
        throw StateError('amount exceeds source caixinha balance');
      }
      tx.set(
        fromLeg,
        Allocation(
          id: fromLeg.id,
          categoryId: fromCategoryId,
          amount: -amount,
          date: date,
          transferId: transferId,
        ).toMap(),
      );
      tx.set(
        toLeg,
        Allocation(
          id: toLeg.id,
          categoryId: toCategoryId,
          amount: amount,
          date: date,
          transferId: transferId,
        ).toMap(),
      );
      tx.set(_balance(fromCategoryId), {'balance': fromBal - amount});
      tx.set(_balance(toCategoryId), {'balance': toBal + amount});
    });
    return transferId;
  }

  /// Removes both legs of a transfer by its shared id, reversing each leg's
  /// effect on its caixinha. The destination can't have already been spent
  /// below the transferred amount.
  Future<void> deleteTransfer(String transferId) async {
    final legs =
        await _allocations.where('transferId', isEqualTo: transferId).get();
    if (legs.docs.isEmpty) return;
    final legInfos = legs.docs
        .map((d) => (
              ref: d.reference,
              cat: d.data()['categoryId'] as String,
              amt: (d.data()['amount'] as num).toDouble(),
            ))
        .toList();
    await _db.runTransaction((tx) async {
      final cats = {for (final l in legInfos) l.cat};
      final before = <String, double>{};
      final categories = <String, Category>{};
      for (final c in cats) {
        before[c] = await _readBalance(tx, _balance(c));
        // A missing category (orphaned by a since-deleted category, matching
        // deleteAllocation's fallback) doesn't allow negative.
        final catSnap = await tx.get(_categories.doc(c));
        categories[c] = catSnap.exists
            ? Category.fromMap(c, catSnap.data()!)
            : Category(id: c, name: '', recurring: false, createdAt: '');
      }
      final after = Map<String, double>.from(before);
      for (final l in legInfos) {
        after[l.cat] = after[l.cat]! - l.amt; // reverse the leg
      }
      for (final c in cats) {
        if (!_catDeltaOk(categories[c]!, before[c]!, after[c]!)) {
          throw StateError('undoing this transfer would overdraw a caixinha');
        }
      }
      for (final l in legInfos) {
        tx.delete(l.ref);
      }
      for (final e in after.entries) {
        tx.set(_balance(e.key), {'balance': e.value});
      }
    });
  }

  // -------------------------------------------------------------------------
  // Expenses (from a caixinha, or straight from the account).
  // -------------------------------------------------------------------------
  Future<Expense> createExpense({
    required String date,
    required double amount,
    String? categoryId,
    String? description,
  }) async {
    if (amount < 0) throw StateError('expense amount cannot be negative');
    final doc = _expenses.doc();
    final expense = Expense(
      id: doc.id,
      date: date,
      amount: amount,
      categoryId: categoryId,
      description: description,
    );
    await _db.runTransaction((tx) async {
      if (categoryId == null) {
        final acct = await _readBalance(tx, _account);
        if (amount > acct + _eps) {
          throw StateError('amount exceeds available balance');
        }
        tx.set(doc, expense.toMap());
        tx.set(_account, {'balance': acct - amount});
      } else {
        final catSnap = await tx.get(_categories.doc(categoryId));
        if (!catSnap.exists) throw StateError('category not found');
        final category = Category.fromMap(categoryId, catSnap.data()!);
        final catBal = await _readBalance(tx, _balance(categoryId));
        final newCat = catBal - amount;
        // A caixinha that already sits at/below 0 and doesn't allow negative
        // is naturally caught here too (any positive `amount` fails
        // `_catDeltaOk`), which is what makes the "toggle off + already
        // negative -> block further gastos" rule (decision #3) fall out of
        // this same check rather than needing a separate one.
        if (!_catDeltaOk(category, catBal, newCat)) {
          throw StateError('amount exceeds available balance');
        }
        tx.set(doc, expense.toMap());
        tx.set(_balance(categoryId), {'balance': newCat});
      }
    });
    return expense;
  }

  /// Edits an expense's amount/date/description. The target (a caixinha vs the
  /// account) is fixed — moving an expense is delete + recreate.
  Future<void> updateExpense(
    String id, {
    required String date,
    required double amount,
    String? categoryId,
    String? description,
  }) async {
    if (amount < 0) throw StateError('expense amount cannot be negative');
    final expense = Expense(
      id: id,
      date: date,
      amount: amount,
      categoryId: categoryId,
      description: description,
    );
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_expenses.doc(id));
      if (!snap.exists) throw StateError('expense not found');
      final data = snap.data()!;
      final oldCat = data['categoryId'] as String?;
      if (oldCat != categoryId) {
        throw StateError('moving an expense between caixinha and account is not supported; delete and recreate');
      }
      final old = (data['amount'] as num).toDouble();
      if (categoryId == null) {
        final acct = await _readBalance(tx, _account);
        final newAcct = acct + old - amount;
        if (newAcct < -_eps) {
          throw StateError('amount exceeds available balance');
        }
        tx.set(_expenses.doc(id), expense.toMap());
        tx.set(_account, {'balance': newAcct});
      } else {
        final catSnap = await tx.get(_categories.doc(categoryId));
        if (!catSnap.exists) throw StateError('category not found');
        final category = Category.fromMap(categoryId, catSnap.data()!);
        final catBal = await _readBalance(tx, _balance(categoryId));
        final newCat = catBal + old - amount;
        if (!_catDeltaOk(category, catBal, newCat)) {
          throw StateError('amount exceeds available balance');
        }
        tx.set(_expenses.doc(id), expense.toMap());
        tx.set(_balance(categoryId), {'balance': newCat});
      }
    });
  }

  Future<void> deleteExpense(String id) async {
    await _db.runTransaction((tx) async {
      final snap = await tx.get(_expenses.doc(id));
      if (!snap.exists) return;
      final data = snap.data()!;
      final cat = data['categoryId'] as String?;
      final amt = (data['amount'] as num).toDouble();
      if (cat == null) {
        final acct = await _readBalance(tx, _account);
        tx.delete(_expenses.doc(id));
        tx.set(_account, {'balance': acct + amt});
      } else {
        final catBal = await _readBalance(tx, _balance(cat));
        tx.delete(_expenses.doc(id));
        tx.set(_balance(cat), {'balance': catBal + amt});
      }
    });
  }

  // -------------------------------------------------------------------------
  // Full restore (from a JSON backup). Wipes the user's data and writes `db`
  // in its place, preserving original ids — used by [ImportExportService].
  //
  // Ordering is what makes this pass the Phase-2 rules: the denormalized
  // balance docs are DELETED FIRST, so the ledger deletes/writes below happen
  // while those docs are absent (the rules' genesis/teardown path skips the
  // per-doc delta check), and the recomputed balance docs are written LAST.
  // The balance docs are NOT part of the backup — they are derived and rebuilt
  // here from the imported ledger via `aggregation_service`.
  // -------------------------------------------------------------------------
  Future<void> replaceAll(AppDb db) async {
    // 0. Validate BEFORE mutating anything, so a bad backup can never leave the
    //    database half-restored (the "trava no meio" failure). A recomputed
    //    negative balance is only legitimate — and only re-materializable by the
    //    rules (catMayHoldNeg on the genesis path) — for an EXISTING spend
    //    caixinha (a frozen/open debt). The account may never be negative, and a
    //    'save' caixinha may never hold a debt; those are corruption, so we
    //    refuse loudly here instead of letting a mid-restore rule denial abort a
    //    partial write. Orphan ids (referenced by the ledger but absent from
    //    db.categories) are NOT written as balance docs at all (see step 4), so
    //    an orphan negative can't reach the rules and isn't checked here.
    final knownKind = {for (final c in db.categories) c.id: c.effectiveKind};
    final catBalances = agg.categoryBalances(db);
    if (agg.accountBalance(db) < 0) {
      throw StateError(
        'cannot restore: the general account balance would be negative — the '
        'backup is inconsistent (reconcile it before importing).',
      );
    }
    for (final entry in catBalances.entries) {
      if (entry.value >= 0) continue;
      final kind = knownKind[entry.key];
      if (kind == null) continue; // orphan: not materialized as a balance doc.
      if (kind != CategoryKind.spend) {
        throw StateError(
          'cannot restore: caixinha "${entry.key}" would have a negative '
          'balance (${entry.value}) but is not a spend caixinha — only spend '
          'caixinhas may hold a debt. The backup is inconsistent.',
        );
      }
    }

    // 1. Remove the derived balance docs (account + every caixinha) first.
    final existingBalances = await _balances.get();
    await _deleteRefs([
      _account,
      ...existingBalances.docs.map((d) => d.reference),
    ]);

    // 2. Delete existing ledger docs (balance docs now absent -> rules skip deltas).
    for (final collection in [_categories, _incomes, _allocations, _expenses]) {
      final existing = await collection.get();
      await _deleteRefs(existing.docs.map((d) => d.reference).toList());
    }

    // 3. Write the new ledger docs (still no balance docs -> genesis path).
    await _setDocs([
      for (final c in db.categories) (_categories.doc(c.id), c.toMap()),
      for (final i in db.incomes) (_incomes.doc(i.id), i.toMap()),
      for (final a in db.allocations) (_allocations.doc(a.id), a.toMap()),
      for (final e in db.expenses) (_expenses.doc(e.id), e.toMap()),
    ]);

    // 4. Write the derived balance docs last (recomputed in step 0). Only
    //    caixinhas that still exist get a balance doc — an orphan id left in the
    //    ledger by an incomplete delete would otherwise produce a junk balance
    //    doc the rules can't police (no category to read), and would fail the
    //    genesis floor if negative. Dropping it keeps the ledger intact while
    //    the display still recomputes correctly by summing that ledger.
    await _setDocs([
      (_account, {'balance': agg.accountBalance(db)}),
      for (final entry in catBalances.entries)
        if (knownKind.containsKey(entry.key))
          (_balance(entry.key), {'balance': entry.value}),
    ]);
  }

  Future<void> _deleteRefs(
    List<DocumentReference<Map<String, dynamic>>> refs,
  ) async {
    for (var i = 0; i < refs.length; i += 400) {
      final batch = _db.batch();
      for (final ref in refs.skip(i).take(400)) {
        batch.delete(ref);
      }
      await batch.commit();
    }
  }

  Future<void> _setDocs(
    List<(DocumentReference<Map<String, dynamic>>, Map<String, dynamic>)> writes,
  ) async {
    for (var i = 0; i < writes.length; i += 400) {
      final batch = _db.batch();
      for (final (ref, data) in writes.skip(i).take(400)) {
        batch.set(ref, data);
      }
      await batch.commit();
    }
  }
}
