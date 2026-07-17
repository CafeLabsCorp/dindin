// Backup/restore JSON compatibility regression (see docs/BACKEND.md,
// "Data model additions (all additive / backward-compatible)"): an OLD
// backup (no `monthlyBudget`, no `transferId`) must import unchanged, a NEW
// backup with those fields must round-trip exactly, and the denormalized
// balance docs must never be part of the backup shape at all (they're
// derived and rebuilt on restore by FirestoreService.replaceAll, not stored).
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/db.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';

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

    test('re-exporting an old-format import does not invent the new fields', () {
      final db = AppDb.fromJson(oldJson);
      final reExported = db.toJson();
      final cat = (reExported['categories'] as List).single as Map<String, dynamic>;
      expect(cat.containsKey('monthlyBudget'), isFalse);
      final alloc = (reExported['allocations'] as List).single as Map<String, dynamic>;
      expect(alloc.containsKey('transferId'), isFalse);
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
    });
  });

  test('AppDb.toJson only ever has the four ledger keys — balance docs are never part of the backup', () {
    final json = AppDb.empty.toJson();
    expect(json.keys.toSet(), {'categories', 'incomes', 'allocations', 'expenses'});
  });
}
