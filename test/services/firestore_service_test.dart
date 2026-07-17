// Regression tests for the client-side money invariants in FirestoreService:
// can't spend more than a caixinha's balance, can't allocate more than the
// account balance, nothing goes negative, edits/deletes adjust balances by
// the exact delta, and transfers are an atomic all-or-nothing pair.
//
// Approach: FirestoreService takes an injectable `FirebaseFirestore` (see its
// constructor), so these tests run against `FakeFirebaseFirestore`
// (in-memory, no emulator/network needed) instead of the real backend. This
// exercises the exact same transaction/batch code paths as production; it
// does NOT exercise firestore.rules (which fake_cloud_firestore doesn't
// evaluate) — that is covered separately by test/rules/ against the real
// Firestore emulator.
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/db.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/services/firestore_service.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreService svc;

  setUp(() {
    fake = FakeFirebaseFirestore();
    svc = FirestoreService(uid: 'u1', firestore: fake);
  });

  Future<double> accountBalance() async {
    final snap = await fake.doc('users/u1/meta/account').get();
    return (snap.data()!['balance'] as num).toDouble();
  }

  Future<double> categoryBalance(String id) async {
    final snap = await fake.doc('users/u1/balances/$id').get();
    return (snap.data()!['balance'] as num).toDouble();
  }

  group('createCategory', () {
    test('creates the category and a zeroed balance doc alongside it', () async {
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      expect(await categoryBalance(cat.id), 0);
    });
  });

  group('income', () {
    test('createIncome adds to the account balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 1000, source: IncomeSource.freela);
      expect(await accountBalance(), 1000);
    });

    test('createIncome rejects a negative amount', () async {
      expect(
        () => svc.createIncome(date: '2026-01-01', amount: -1, source: IncomeSource.freela),
        throwsStateError,
      );
    });

    test('updateIncome adjusts the account balance by the exact delta', () async {
      final income = await svc.createIncome(date: '2026-01-01', amount: 1000, source: IncomeSource.freela);
      await svc.updateIncome(income.id, date: '2026-01-01', amount: 1300, source: IncomeSource.freela);
      expect(await accountBalance(), 1300);
    });

    test('updateIncome refuses to lower the account balance below zero', () async {
      final income = await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Casa', recurring: true);
      await svc.createAllocation(categoryId: cat.id, amount: 100, date: '2026-01-02');
      // account is now 0 (100 income - 100 allocated); lowering THIS income
      // to 50 would move the account by (50 - 100) = -50, taking it negative.
      expect(
        () => svc.updateIncome(income.id, date: '2026-01-01', amount: 50, source: IncomeSource.freela),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteIncome reverts the account balance', () async {
      final income = await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      await svc.createIncome(date: '2026-01-02', amount: 200, source: IncomeSource.outro);
      await svc.deleteIncome(income.id);
      expect(await accountBalance(), 200);
    });

    test('deleteIncome refuses to overdraw the account', () async {
      final income = await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Casa', recurring: true);
      await svc.createAllocation(categoryId: cat.id, amount: 500, date: '2026-01-02');
      expect(() => svc.deleteIncome(income.id), throwsA(isA<StateError>()));
    });
  });

  group('allocations', () {
    test('createAllocation cannot exceed the account balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      expect(
        () => svc.createAllocation(categoryId: cat.id, amount: 101, date: '2026-01-02'),
        throwsA(isA<StateError>()),
      );
      // account balance is untouched by the rejected attempt.
      expect(await accountBalance(), 100);
    });

    test('createAllocation moves money from account to caixinha', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 300, date: '2026-01-02');
      expect(await accountBalance(), 200);
      expect(await categoryBalance(cat.id), 300);
    });

    test('updateAllocation edits the amount and adjusts both balances by the delta', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      final alloc = await svc.createAllocation(categoryId: cat.id, amount: 300, date: '2026-01-02');
      await svc.updateAllocation(alloc.id, categoryId: cat.id, amount: 200, date: '2026-01-02');
      expect(await accountBalance(), 300); // 500 - 200
      expect(await categoryBalance(cat.id), 200);
    });

    test('updateAllocation refuses to reduce below what has already been spent from the caixinha', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      final alloc = await svc.createAllocation(categoryId: cat.id, amount: 300, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 250, categoryId: cat.id);
      // caixinha balance is 50; reducing the allocation to 100 would need -200,
      // pushing the caixinha to -150.
      expect(
        () => svc.updateAllocation(alloc.id, categoryId: cat.id, amount: 100, date: '2026-01-02'),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteAllocation reverts both the account and the caixinha balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      final alloc = await svc.createAllocation(categoryId: cat.id, amount: 300, date: '2026-01-02');
      await svc.deleteAllocation(alloc.id);
      expect(await accountBalance(), 500);
      expect(await categoryBalance(cat.id), 0);
    });

    test('deleteAllocation refuses to leave the caixinha negative', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      final alloc = await svc.createAllocation(categoryId: cat.id, amount: 300, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 250, categoryId: cat.id);
      expect(() => svc.deleteAllocation(alloc.id), throwsA(isA<StateError>()));
    });
  });

  group('expenses', () {
    test('createExpense against a caixinha cannot exceed its balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 100, date: '2026-01-02');
      expect(
        () => svc.createExpense(date: '2026-01-03', amount: 101, categoryId: cat.id),
        throwsA(isA<StateError>()),
      );
      expect(await categoryBalance(cat.id), 100); // unchanged
    });

    test('createExpense directly against the account cannot exceed the account balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      expect(
        () => svc.createExpense(date: '2026-01-02', amount: 101),
        throwsA(isA<StateError>()),
      );
    });

    test('updateExpense from 50 to 30 gives 20 back to the caixinha balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 200, date: '2026-01-02');
      final expense = await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: cat.id);
      expect(await categoryBalance(cat.id), 150); // 200 - 50

      await svc.updateExpense(expense.id, date: '2026-01-03', amount: 30, categoryId: cat.id);
      expect(await categoryBalance(cat.id), 170); // 200 - 30, i.e. +20 back
    });

    test('updateExpense on an account-level expense adjusts the account balance by the delta', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final expense = await svc.createExpense(date: '2026-01-02', amount: 100);
      expect(await accountBalance(), 400);
      await svc.updateExpense(expense.id, date: '2026-01-02', amount: 60);
      expect(await accountBalance(), 440); // 500 - 60
    });

    test('deleteExpense reverts the caixinha balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 200, date: '2026-01-02');
      final expense = await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: cat.id);
      await svc.deleteExpense(expense.id);
      expect(await categoryBalance(cat.id), 200);
    });

    test('deleteExpense reverts the account balance for an account-level expense', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final expense = await svc.createExpense(date: '2026-01-02', amount: 100);
      await svc.deleteExpense(expense.id);
      expect(await accountBalance(), 500);
    });
  });

  group('transfers', () {
    test('createTransfer moves balance between caixinhas and leaves the account untouched', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 300, date: '2026-01-02');

      final transferId = await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 120,
        date: '2026-01-03',
      );

      expect(transferId, isNotEmpty);
      expect(await accountBalance(), 200); // unaffected by the transfer itself
      expect(await categoryBalance(origem.id), 180); // 300 - 120
      expect(await categoryBalance(destino.id), 120);

      // Both legs share the transferId and net to zero.
      final legs = await fake
          .collection('users/u1/allocations')
          .where('transferId', isEqualTo: transferId)
          .get();
      expect(legs.docs.length, 2);
      final sum = legs.docs.fold<double>(0, (s, d) => s + (d.data()['amount'] as num).toDouble());
      expect(sum, 0);
    });

    test('createTransfer cannot exceed the source caixinha balance', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 100, date: '2026-01-02');

      expect(
        () => svc.createTransfer(
          fromCategoryId: origem.id,
          toCategoryId: destino.id,
          amount: 101,
          date: '2026-01-03',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await categoryBalance(origem.id), 100); // unchanged
    });

    test('createTransfer rejects same source and destination', () async {
      final cat = await svc.createCategory(name: 'Casa', recurring: true);
      expect(
        () => svc.createTransfer(
          fromCategoryId: cat.id,
          toCategoryId: cat.id,
          amount: 10,
          date: '2026-01-03',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('deleteTransfer removes BOTH legs and reverses both balances', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 300, date: '2026-01-02');
      final transferId = await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 120,
        date: '2026-01-03',
      );

      await svc.deleteTransfer(transferId);

      expect(await categoryBalance(origem.id), 300); // back to before the transfer
      expect(await categoryBalance(destino.id), 0);
      final remainingLegs = await fake
          .collection('users/u1/allocations')
          .where('transferId', isEqualTo: transferId)
          .get();
      expect(remainingLegs.docs, isEmpty);
    });

    test('deleteAllocation on a transfer leg deletes both legs via deleteTransfer (no half-transfer left behind)', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 300, date: '2026-01-02');
      final transferId = await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 120,
        date: '2026-01-03',
      );
      final legs = await fake
          .collection('users/u1/allocations')
          .where('transferId', isEqualTo: transferId)
          .get();
      final oneLegId = legs.docs.first.id;

      await svc.deleteAllocation(oneLegId);

      final remaining = await fake
          .collection('users/u1/allocations')
          .where('transferId', isEqualTo: transferId)
          .get();
      expect(remaining.docs, isEmpty); // both legs gone, not just the one requested
      expect(await categoryBalance(origem.id), 300);
      expect(await categoryBalance(destino.id), 0);
    });

    test('deleteTransfer refuses to undo a transfer if the destination was already spent below the moved amount', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 300, date: '2026-01-02');
      final transferId = await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 120,
        date: '2026-01-03',
      );
      await svc.createExpense(date: '2026-01-04', amount: 100, categoryId: destino.id);
      // destino balance is now 20; undoing the transfer needs -120 -> negative.
      expect(() => svc.deleteTransfer(transferId), throwsA(isA<StateError>()));
    });
  });

  group('deleteCategory cascade', () {
    test('deletes the category, its balance doc, and its ledger rows, restoring plain-allocation money to the account', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 200, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: cat.id);

      await svc.deleteCategory(cat.id);

      expect(await accountBalance(), 500 - 200 + 200); // the 200 allocation is reversed
      final catSnap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(catSnap.exists, isFalse);
      final balSnap = await fake.doc('users/u1/balances/${cat.id}').get();
      expect(balSnap.exists, isFalse);
      final remainingAllocs = await fake
          .collection('users/u1/allocations')
          .where('categoryId', isEqualTo: cat.id)
          .get();
      expect(remainingAllocs.docs, isEmpty);
      final remainingExps = await fake
          .collection('users/u1/expenses')
          .where('categoryId', isEqualTo: cat.id)
          .get();
      expect(remainingExps.docs, isEmpty);
    });

    test('a transfer leg does not get double-reversed into the account (only plain allocations are summed back)', () async {
      await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true);
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 300, date: '2026-01-02');
      await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 100,
        date: '2026-01-03',
      );
      // account = 500 - 300 (plain allocation) = 200. The transfer doesn't touch it.
      expect(await accountBalance(), 200);

      await svc.deleteCategory(destino.id);
      // destino only held a transfer leg (no plain allocation) -> account
      // reversal sum is 0 -> account balance stays 200, not 300.
      expect(await accountBalance(), 200);
    });
  });

  group('replaceAll (JSON restore)', () {
    test('wipes existing data and rebuilds balance docs from the imported ledger', () async {
      // Pre-existing data that must be fully wiped by the restore.
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final oldCat = await svc.createCategory(name: 'old', recurring: false);
      await svc.createAllocation(categoryId: oldCat.id, amount: 50, date: '2026-01-02');

      const importedCategory = Category(
        id: 'c1',
        name: 'Casa',
        recurring: true,
        createdAt: '2026-01-01',
      );
      const importedIncome = Income(
        id: 'i1',
        date: '2026-01-01',
        amount: 1000,
        source: IncomeSource.freela,
      );
      const importedAllocation = Allocation(
        id: 'a1',
        categoryId: 'c1',
        amount: 400,
        date: '2026-01-02',
      );
      final imported = AppDb(
        categories: const [importedCategory],
        incomes: const [importedIncome],
        allocations: const [importedAllocation],
        expenses: const [],
      );

      await svc.replaceAll(imported);

      final db = await svc.fetchAll();
      expect(db.categories.map((c) => c.id), ['c1']);
      expect(db.incomes.single.amount, 1000);
      expect(await accountBalance(), 1000 - 400); // matches aggregation_service math
      expect(await categoryBalance('c1'), 400);

      // The old category/allocation are gone, not merged in.
      expect(db.categories.any((c) => c.id == oldCat.id), isFalse);
    });

    test('restoring an empty AppDb clears all ledger and balance docs', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: cat.id, amount: 50, date: '2026-01-02');

      await svc.replaceAll(AppDb.empty);

      final db = await svc.fetchAll();
      expect(db.categories, isEmpty);
      expect(db.incomes, isEmpty);
      expect(db.allocations, isEmpty);
      expect(await accountBalance(), 0);
    });
  });
}
