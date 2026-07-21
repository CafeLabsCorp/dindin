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
import 'package:dindin/models/expense.dart';
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

  group('allowNegative (caixinha debt) — client-side pre-check parity with catDeltaOk', () {
    // These exercise `_catDeltaOk` (the client's mirror of `firestore.rules`'
    // `catDeltaOk`/`catAllowsNeg`) through the public API. They do NOT touch
    // firestore.rules itself (fake_cloud_firestore doesn't evaluate rules) —
    // that half of the invariant is covered by test/rules/rules.test.mjs
    // against the real emulator. Kept here because it's the same real
    // production code path (`FirestoreService`) and is cheap/fast to run.

    test('createExpense deepens an existing debt when allowNegative is ON', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(
        name: 'Lazer',
        recurring: false,
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      await svc.createAllocation(categoryId: cat.id, amount: 20, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: cat.id);
      expect(await categoryBalance(cat.id), -30); // 20 - 50
    });

    test('createExpense is refused when allowNegative is OFF and the caixinha is already negative', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final onCat = await svc.createCategory(
        name: 'Lazer',
        recurring: false,
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      await svc.createAllocation(categoryId: onCat.id, amount: 20, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: onCat.id); // -> -30
      // Freeze the debt: toggle allowNegative back off (allowed per the docs
      // even while negative — it just refuses to deepen further from here).
      await svc.updateCategory(onCat.id, allowNegative: false);

      expect(
        () => svc.createExpense(date: '2026-01-04', amount: 1, categoryId: onCat.id),
        throwsA(isA<StateError>()),
      );
      expect(await categoryBalance(onCat.id), -30); // unchanged by the rejected attempt
    });

    test('allocation that only partially pays down a frozen debt (still negative) is allowed', () async {
      await svc.createIncome(date: '2026-01-01', amount: 200, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      // Manufacture a debt directly on the balance doc, mirroring a caixinha
      // that was allowNegative:true, went negative, then got toggled off.
      await fake.doc('users/u1/balances/${cat.id}').set({'balance': -50.0});

      await svc.createAllocation(categoryId: cat.id, amount: 20, date: '2026-01-02');
      expect(await categoryBalance(cat.id), -30); // -50 + 20, delta >= 0 -> allowed even off+negative
    });

    test('paying a frozen debt back to >= 0 unblocks normal expenses again', () async {
      await svc.createIncome(date: '2026-01-01', amount: 200, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      await fake.doc('users/u1/balances/${cat.id}').set({'balance': -30.0});

      await svc.createAllocation(categoryId: cat.id, amount: 40, date: '2026-01-02');
      expect(await categoryBalance(cat.id), 10);

      await svc.createExpense(date: '2026-01-03', amount: 5, categoryId: cat.id);
      expect(await categoryBalance(cat.id), 5); // back to ordinary non-negative gating
    });

    test('a `save` caixinha cannot go negative even with allowNegative:true stored on it', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(
        name: 'Reserva',
        recurring: false,
        kind: CategoryKind.save,
        allowNegative: true, // meaningless for `save`, per Category.allowsNegativeBalance
      );
      await svc.createAllocation(categoryId: cat.id, amount: 10, date: '2026-01-02');
      expect(
        () => svc.createExpense(date: '2026-01-03', amount: 20, categoryId: cat.id),
        throwsA(isA<StateError>()),
      );
      expect(await categoryBalance(cat.id), 10); // unchanged
    });

    test('createTransfer out of an allowNegative source can deepen its debt', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final origem = await svc.createCategory(
        name: 'Casa',
        recurring: true,
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 10, date: '2026-01-02');

      await svc.createTransfer(
        fromCategoryId: origem.id,
        toCategoryId: destino.id,
        amount: 25,
        date: '2026-01-03',
      );
      expect(await categoryBalance(origem.id), -15); // 10 - 25
      expect(await categoryBalance(destino.id), 25);
    });

    test('createTransfer out of a NON-eligible source that would go negative is refused', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final origem = await svc.createCategory(name: 'Casa', recurring: true); // allowNegative unset -> off
      final destino = await svc.createCategory(name: 'Lazer', recurring: false);
      await svc.createAllocation(categoryId: origem.id, amount: 10, date: '2026-01-02');

      expect(
        () => svc.createTransfer(
          fromCategoryId: origem.id,
          toCategoryId: destino.id,
          amount: 25,
          date: '2026-01-03',
        ),
        throwsA(isA<StateError>()),
      );
      expect(await categoryBalance(origem.id), 10); // unchanged
    });
  });

  group('updateCategory / deleteCategory: catDebtFree guard (spend->save conversion & delete)', () {
    // Mirrors firestore.rules' `catDebtFree` + `convertsSpendToSave`,
    // exercised at the client/service layer (see test/rules/rules.test.mjs
    // for the server-side half of this same invariant).

    test('updateCategory throws a StateError with "settle the debt" converting spend->save while the balance is negative', () async {
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      await fake.doc('users/u1/balances/${cat.id}').set({'balance': -10.0});

      await expectLater(
        () => svc.updateCategory(cat.id, kind: CategoryKind.save),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('settle the debt'),
          ),
        ),
      );
      // The category is left untouched (still spend) by the rejected attempt.
      final snap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(Category.fromMap(cat.id, snap.data()!).effectiveKind, CategoryKind.spend);
    });

    test('updateCategory allows converting spend->save when the balance is exactly 0', () async {
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      // balance doc is already 0 from createCategory.
      await svc.updateCategory(cat.id, kind: CategoryKind.save);
      final snap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(Category.fromMap(cat.id, snap.data()!).effectiveKind, CategoryKind.save);
    });

    test('updateCategory allows converting spend->save when the balance is positive', () async {
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      await fake.doc('users/u1/balances/${cat.id}').set({'balance': 30.0});
      await svc.updateCategory(cat.id, kind: CategoryKind.save);
      final snap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(Category.fromMap(cat.id, snap.data()!).effectiveKind, CategoryKind.save);
    });

    test('updateCategory allows non-conversion edits on an indebted spend caixinha (rename, budget, allowNegative toggle)', () async {
      final cat = await svc.createCategory(
        name: 'Lazer',
        recurring: false,
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      await fake.doc('users/u1/balances/${cat.id}').set({'balance': -20.0});

      // None of these are a spend->save conversion, so the debt never blocks them.
      await svc.updateCategory(cat.id, name: 'Novo nome');
      await svc.updateCategory(cat.id, monthlyBudget: 100);
      await svc.updateCategory(cat.id, allowNegative: false); // freeze the debt
      await svc.updateCategory(cat.id, allowNegative: true); // unfreeze it again

      final snap = await fake.doc('users/u1/categories/${cat.id}').get();
      final updated = Category.fromMap(cat.id, snap.data()!);
      expect(updated.name, 'Novo nome');
      expect(updated.monthlyBudget, 100);
      expect(updated.allowNegative, isTrue);
      expect(updated.effectiveKind, CategoryKind.spend); // never converted
    });

    test('updateCategory allows save->spend conversion regardless of balance (the guard only applies to the other direction)', () async {
      final cat = await svc.createCategory(name: 'Reserva', recurring: false, kind: CategoryKind.save);
      // A 'save' caixinha's balance is never negative in practice, but the
      // guard's short-circuit (before.kind == 'spend') means it wouldn't
      // matter even if it were.
      await svc.updateCategory(cat.id, kind: CategoryKind.spend);
      final snap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(Category.fromMap(cat.id, snap.data()!).effectiveKind, CategoryKind.spend);
    });

    test('deleteCategory throws a StateError with "settle the debt" when the balance is negative, leaving every doc untouched', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(
        name: 'Lazer',
        recurring: false,
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      final alloc = await svc.createAllocation(categoryId: cat.id, amount: 20, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 50, categoryId: cat.id); // -> balance -30

      await expectLater(
        () => svc.deleteCategory(cat.id),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('settle the debt'),
          ),
        ),
      );

      // Nothing was mutated: the transaction aborted atomically.
      final catSnap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(catSnap.exists, isTrue);
      final balSnap = await fake.doc('users/u1/balances/${cat.id}').get();
      expect((balSnap.data()!['balance'] as num).toDouble(), -30);
      final allocSnap = await fake.doc('users/u1/allocations/${alloc.id}').get();
      expect(allocSnap.exists, isTrue);
      final expsSnap = await fake
          .collection('users/u1/expenses')
          .where('categoryId', isEqualTo: cat.id)
          .get();
      expect(expsSnap.docs, hasLength(1));
      expect(await accountBalance(), 80); // 100 - 20, untouched by the rejected delete
    });

    test('deleteCategory succeeds and cascades normally when the balance is exactly 0', () async {
      await svc.createIncome(date: '2026-01-01', amount: 100, source: IncomeSource.freela);
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      await svc.createAllocation(categoryId: cat.id, amount: 30, date: '2026-01-02');
      await svc.createExpense(date: '2026-01-03', amount: 30, categoryId: cat.id); // balance exactly 0

      await svc.deleteCategory(cat.id);

      final catSnap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(catSnap.exists, isFalse);
    });

    test('deleteCategory succeeds when the balance doc was never created (a missing doc reads as debt-free)', () async {
      final cat = await svc.createCategory(name: 'Lazer', recurring: false, kind: CategoryKind.spend);
      // createCategory creates a zeroed balance doc alongside it; delete it
      // directly to simulate the doc being genuinely absent.
      await fake.doc('users/u1/balances/${cat.id}').delete();

      await svc.deleteCategory(cat.id);

      final catSnap = await fake.doc('users/u1/categories/${cat.id}').get();
      expect(catSnap.exists, isFalse);
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

    // -- F1 fix: step-0 pre-validation + frozen-debt genesis re-materialization --

    test(
      'restoring a backup where a spend caixinha has a frozen (allowNegative '
      'OFF) debt completes fully and materializes the negative balance doc',
      () async {
        const debtCategory = Category(
          id: 'c1',
          name: 'Lazer',
          recurring: false,
          createdAt: '2026-01-01',
          kind: CategoryKind.spend,
          allowNegative: false, // frozen: toggle off, but the debt survives restore
        );
        const income = Income(
          id: 'i1',
          date: '2026-01-01',
          amount: 100,
          source: IncomeSource.freela,
        );
        const allocation = Allocation(
          id: 'a1',
          categoryId: 'c1',
          amount: 30,
          date: '2026-01-02',
        );
        const expense = Expense(
          id: 'e1',
          date: '2026-01-03',
          amount: 80, // 30 allocated - 80 spent = -50 (the frozen debt)
          categoryId: 'c1',
        );
        final backup = AppDb(
          categories: const [debtCategory],
          incomes: const [income],
          allocations: const [allocation],
          expenses: const [expense],
        );

        await svc.replaceAll(backup);

        // Nothing partial: the full ledger is present...
        final db = await svc.fetchAll();
        expect(db.categories.map((c) => c.id), ['c1']);
        expect(db.incomes.single.id, 'i1');
        expect(db.allocations.single.id, 'a1');
        expect(db.expenses.single.id, 'e1');
        // ...and the frozen debt is materialized as a negative balance doc.
        expect(await categoryBalance('c1'), -50);
        expect(await accountBalance(), 100 - 30); // 70, untouched by the debt
      },
    );

    test(
      "restoring a backup where a 'save' caixinha sums negative throws at "
      'step 0 and leaves the database completely untouched (no partial restore)',
      () async {
        // Pre-existing data that must survive intact if the restore is refused.
        await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);
        final existingCat = await svc.createCategory(name: 'old', recurring: false);

        const saveCategory = Category(
          id: 'c1',
          name: 'Reserva',
          recurring: false,
          createdAt: '2026-01-01',
          kind: CategoryKind.save,
        );
        const allocation = Allocation(
          id: 'a1',
          categoryId: 'c1',
          amount: 30,
          date: '2026-01-02',
        );
        const expense = Expense(
          id: 'e1',
          date: '2026-01-03',
          amount: 80, // 30 - 80 = -50: a 'save' caixinha may never hold a debt
          categoryId: 'c1',
        );
        final badBackup = AppDb(
          categories: const [saveCategory],
          incomes: const [],
          allocations: const [allocation],
          expenses: const [expense],
        );

        await expectLater(
          () => svc.replaceAll(badBackup),
          throwsA(isA<StateError>()),
        );

        // Nothing was mutated: the pre-existing data is exactly as it was.
        final db = await svc.fetchAll();
        expect(db.categories.map((c) => c.id), [existingCat.id]);
        expect(db.incomes.single.amount, 500);
        expect(await accountBalance(), 500);
      },
    );

    test(
      'restoring a backup where the account itself would be negative throws '
      'at step 0 and leaves the database completely untouched',
      () async {
        await svc.createIncome(date: '2026-01-01', amount: 500, source: IncomeSource.freela);

        const income = Income(
          id: 'i1',
          date: '2026-01-01',
          amount: 100,
          source: IncomeSource.freela,
        );
        const expense = Expense(
          id: 'e1',
          date: '2026-01-02',
          amount: 300, // 100 - 300 = -200: the account may never go negative
        );
        final badBackup = AppDb(
          categories: const [],
          incomes: const [income],
          allocations: const [],
          expenses: const [expense],
        );

        await expectLater(
          () => svc.replaceAll(badBackup),
          throwsA(isA<StateError>()),
        );

        final db = await svc.fetchAll();
        expect(db.incomes.single.amount, 500); // untouched pre-existing data
      },
    );

    test(
      'restoring a backup with an orphan negative in the ledger (an '
      'allocation/expense referencing a categoryId absent from db.categories) '
      'succeeds, writes no balance doc for the orphan, and keeps the ledger intact',
      () async {
        const income = Income(
          id: 'i1',
          date: '2026-01-01',
          amount: 100,
          source: IncomeSource.freela,
        );
        // 'ghost' is never listed in db.categories — an orphan id, as if a
        // category delete had left ledger docs behind (defect 2's scenario).
        const orphanAllocation = Allocation(
          id: 'a1',
          categoryId: 'ghost',
          amount: 30,
          date: '2026-01-02',
        );
        const orphanExpense = Expense(
          id: 'e1',
          date: '2026-01-03',
          amount: 80, // 30 - 80 = -50, negative, but 'ghost' has no category doc
          categoryId: 'ghost',
        );
        final backup = AppDb(
          categories: const [], // no category for 'ghost'
          incomes: const [income],
          allocations: const [orphanAllocation],
          expenses: const [orphanExpense],
        );

        await svc.replaceAll(backup);

        // Ledger is written intact (the orphan docs themselves are restored)...
        final db = await svc.fetchAll();
        expect(db.allocations.single.categoryId, 'ghost');
        expect(db.expenses.single.categoryId, 'ghost');
        // ...but no balances/ghost doc was written for the orphan (step 4 skips
        // any categoryId not in db.categories) — reading it must find nothing.
        final orphanBalanceSnap = await fake.doc('users/u1/balances/ghost').get();
        expect(orphanBalanceSnap.exists, isFalse);
        // The account balance still subtracts the allocation (accountBalance
        // sums ALL allocations regardless of whether the category still
        // exists — only the CAIXINHA balance doc is skipped for the orphan).
        expect(await accountBalance(), 100 - 30); // 70
      },
    );
  });
}
