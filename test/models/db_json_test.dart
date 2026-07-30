// Backup/restore JSON compatibility regression (see docs/BACKEND.md,
// "Data model additions (all additive / backward-compatible)"): an OLD
// backup (no `monthlyBudget`, no `transferId`) must import unchanged, a NEW
// backup with those fields must round-trip exactly, and the denormalized
// balance docs must never be part of the backup shape at all (they're
// derived and rebuilt on restore by FirestoreService.replaceAll, not stored).
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/db.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/expense_source.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';

void main() {
  group('old-format backup (pre monthlyBudget/transferId) imports unchanged', () {
    final oldJson = {
      'categories': [
        {'id': 'c1', 'name': 'Casa', 'recurring': true, 'createdAt': '2026-01-01'},
      ],
      'incomes': [
        {'id': 'i1', 'date': '2026-01-01', 'amount': 1000, 'source': 'freela'},
      ],
      'allocations': [
        {'id': 'a1', 'categoryId': 'c1', 'amount': 400, 'date': '2026-01-02'},
      ],
      'expenses': [
        {'id': 'e1', 'date': '2026-01-03', 'amount': 100, 'categoryId': 'c1'},
      ],
    };

    test('parses without throwing', () {
      final db = AppDb.fromJson(oldJson);
      expect(db.categories.single.id, 'c1');
      expect(db.incomes.single.amount, 1000);
      expect(db.allocations.single.amount, 400);
      expect(db.expenses.single.amount, 100);
    });

    test('missing monthlyBudget becomes null, not a crash or a zero', () {
      final db = AppDb.fromJson(oldJson);
      expect(db.categories.single.monthlyBudget, isNull);
    });

    test('missing transferId becomes null (a plain allocation, not a transfer)', () {
      final db = AppDb.fromJson(oldJson);
      expect(db.allocations.single.transferId, isNull);
      expect(db.allocations.single.isTransfer, isFalse);
    });

    test('missing subscriptions key becomes an empty list, not a crash', () {
      final db = AppDb.fromJson(oldJson);
      expect(db.subscriptions, isEmpty);
    });

    test('missing installmentPurchases key becomes an empty list, not a crash', () {
      final db = AppDb.fromJson(oldJson);
      expect(db.installmentPurchases, isEmpty);
    });

    test('re-exporting an old-format import does not invent the new fields', () {
      final db = AppDb.fromJson(oldJson);
      final reExported = db.toJson();
      final cat = (reExported['categories'] as List).single as Map<String, dynamic>;
      expect(cat.containsKey('monthlyBudget'), isFalse);
      final alloc = (reExported['allocations'] as List).single as Map<String, dynamic>;
      expect(alloc.containsKey('transferId'), isFalse);
      expect(reExported['subscriptions'], isEmpty);
      expect(reExported['installmentPurchases'], isEmpty);
      // An expense predating the origin link stays a plain manual expense on
      // the way back out — no invented sourceType/sourceId.
      final exp = (reExported['expenses'] as List).single as Map<String, dynamic>;
      expect(exp.containsKey('sourceType'), isFalse);
      expect(exp.containsKey('sourceId'), isFalse);
      expect(db.expenses.single.isGenerated, isFalse);
    });
  });

  group('expense origin link (sourceType/sourceId) survives a backup round trip', () {
    test('a generated expense keeps both fields through toJson -> fromJson', () {
      final db = AppDb(
        categories: const [],
        incomes: const [],
        allocations: const [],
        expenses: const [
          Expense(
            id: 'e1',
            date: '2026-01-05',
            amount: 39.90,
            description: 'Netflix',
            sourceType: 'subscription',
            sourceId: 's1',
          ),
        ],
      );

      final restored = AppDb.fromJson(jsonDecode(jsonEncode(db.toJson())) as Map<String, dynamic>);

      final exp = restored.expenses.single;
      expect(exp.sourceType, 'subscription');
      expect(exp.sourceId, 's1');
      expect(exp.source, ExpenseSource.subscription);
      expect(exp.isGenerated, isTrue);
    });

    test('a source kind this build does not know is preserved, not dropped', () {
      // Expense.sourceType is stored raw precisely so a value written by a
      // newer build survives an export/import here instead of being silently
      // erased on the way back out.
      final restored = AppDb.fromJson({
        'categories': [],
        'incomes': [],
        'allocations': [],
        'expenses': [
          {
            'id': 'e1',
            'date': '2026-01-05',
            'amount': 10,
            'sourceType': 'somethingNewer',
            'sourceId': 'x1',
          },
        ],
      });

      final exp = restored.expenses.single;
      expect(exp.sourceType, 'somethingNewer');
      expect(exp.isGenerated, isTrue, reason: 'it still came from something');
      expect(exp.source, isNull, reason: 'but this build cannot say what');
      expect(
        (restored.toJson()['expenses'] as List).single,
        containsPair('sourceType', 'somethingNewer'),
      );
    });
  });

  group('new-format backup (with monthlyBudget and transferId) round-trips', () {
    final newDb = AppDb(
      categories: const [
        Category(
          id: 'c1',
          name: 'Lazer',
          recurring: false,
          createdAt: '2026-01-01',
          monthlyBudget: 200,
        ),
        Category(id: 'c2', name: 'Casa', recurring: true, createdAt: '2026-01-01'),
      ],
      incomes: const [
        Income(id: 'i1', date: '2026-01-01', amount: 1000, source: IncomeSource.freela),
      ],
      allocations: const [
        Allocation(id: 'a1', categoryId: 'c1', amount: 200, date: '2026-01-02'),
        Allocation(
          id: 't1a',
          categoryId: 'c1',
          amount: -50,
          date: '2026-01-03',
          transferId: 'transfer-1',
        ),
        Allocation(
          id: 't1b',
          categoryId: 'c2',
          amount: 50,
          date: '2026-01-03',
          transferId: 'transfer-1',
        ),
      ],
      expenses: const [
        Expense(id: 'e1', date: '2026-01-04', amount: 30, categoryId: 'c1'),
      ],
      subscriptions: const [
        Subscription(id: 's1', name: 'Netflix', amount: 39.9, dueDay: 5, createdAt: '2026-01-01'),
      ],
      installmentPurchases: const [
        InstallmentPurchase(
          id: 'p1',
          name: 'Notebook Dell',
          totalAmount: 300,
          installments: 3,
          purchaseDate: '2026-01-05',
          firstChargeDate: '2026-02-05',
          createdAt: '2026-01-05',
          chargedInstallments: 1,
        ),
      ],
    );

    test('toJson -> fromJson reproduces every field exactly', () {
      final json = newDb.toJson();
      final restored = AppDb.fromJson(json);

      final cat = restored.categories.firstWhere((c) => c.id == 'c1');
      expect(cat.monthlyBudget, 200);

      final catNoLimit = restored.categories.firstWhere((c) => c.id == 'c2');
      expect(catNoLimit.monthlyBudget, isNull);

      final transferLegs = restored.allocations.where((a) => a.transferId == 'transfer-1');
      expect(transferLegs.length, 2);
      expect(transferLegs.map((a) => a.amount).reduce((a, b) => a + b), 0);

      final plainAlloc = restored.allocations.firstWhere((a) => a.id == 'a1');
      expect(plainAlloc.transferId, isNull);
      expect(plainAlloc.isTransfer, isFalse);

      expect(restored.subscriptions.single.name, 'Netflix');
      expect(restored.subscriptions.single.dueDay, 5);

      expect(restored.installmentPurchases.single.name, 'Notebook Dell');
      expect(restored.installmentPurchases.single.installments, 3);
      expect(restored.installmentPurchases.single.chargedInstallments, 1);
    });
  });

  test('AppDb.toJson only ever has the six ledger keys — balance docs are never part of the backup', () {
    final json = AppDb.empty.toJson();
    expect(
      json.keys.toSet(),
      {'categories', 'incomes', 'allocations', 'expenses', 'subscriptions', 'installmentPurchases'},
    );
  });
}
