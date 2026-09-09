import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/allocation.dart';
import 'package:dindin/models/category.dart';
import 'package:dindin/models/db.dart';
import 'package:dindin/models/expense.dart';
import 'package:dindin/models/income.dart';
import 'package:dindin/models/income_source.dart';
import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/services/backup_validation.dart';

const _validCategory = Category(
  id: 'c1',
  name: 'Mercado',
  recurring: false,
  createdAt: '2026-01-01',
);

void main() {
  group('validateBackupShape — valid backups pass through untouched', () {
    test('an empty backup is valid', () {
      expect(() => validateBackupShape(AppDb.empty), returnsNormally);
    });

    test('a normal, well-within-bounds backup is valid', () {
      final db = AppDb(
        categories: const [_validCategory],
        incomes: const [
          Income(id: 'i1', date: '2026-01-01', amount: 100, source: IncomeSource.freela),
        ],
        allocations: const [
          Allocation(id: 'a1', categoryId: 'c1', amount: 50, date: '2026-01-02'),
        ],
        expenses: const [
          Expense(id: 'e1', date: '2026-01-03', amount: 20, categoryId: 'c1', description: 'Feira'),
        ],
        subscriptions: const [
          Subscription(id: 's1', name: 'Netflix', amount: 39.9, dueDay: 10, createdAt: '2026-01-01'),
        ],
        installmentPurchases: const [
          InstallmentPurchase(
            id: 'p1',
            name: 'Notebook',
            totalAmount: 1200,
            installments: 12,
            purchaseDate: '2026-01-01',
            firstChargeDate: '2026-02-01',
            createdAt: '2026-01-01',
          ),
        ],
      );
      expect(() => validateBackupShape(db), returnsNormally);
    });
  });

  group('validateBackupShape — rejects what firestore.rules would reject, BEFORE any write', () {
    test('a category name over 120 chars is rejected', () {
      final db = AppDb.empty.copyWithCategories([
        Category(id: 'c1', name: 'x' * 121, recurring: false, createdAt: '2026-01-01'),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('an invalid (too-short) ISO date is rejected', () {
      final db = AppDb.empty.copyWithCategories([
        const Category(id: 'c1', name: 'Mercado', recurring: false, createdAt: '2026'),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('an income description over 280 chars is rejected', () {
      final db = AppDb(
        categories: const [],
        incomes: [
          Income(
            id: 'i1',
            date: '2026-01-01',
            amount: 100,
            source: IncomeSource.freela,
            description: 'x' * 281,
          ),
        ],
        allocations: const [],
        expenses: const [],
      );
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('an income amount above the ceiling (Infinity-adjacent abuse case) is rejected', () {
      final db = AppDb(
        categories: const [],
        incomes: const [
          Income(id: 'i1', date: '2026-01-01', amount: 2000000000, source: IncomeSource.freela),
        ],
        allocations: const [],
        expenses: const [],
      );
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('a negative plain allocation (no transferId) is rejected', () {
      final db = AppDb(
        categories: const [_validCategory],
        incomes: const [],
        allocations: const [
          Allocation(id: 'a1', categoryId: 'c1', amount: -10, date: '2026-01-02'),
        ],
        expenses: const [],
      );
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('a transfer leg (has transferId) MAY be negative', () {
      final db = AppDb(
        categories: const [_validCategory],
        incomes: const [],
        allocations: const [
          Allocation(id: 'a1', categoryId: 'c1', amount: -10, date: '2026-01-02', transferId: 't1'),
        ],
        expenses: const [],
      );
      expect(() => validateBackupShape(db), returnsNormally);
    });

    test('an expense with sourceType but no sourceId is rejected (must be both or neither)', () {
      final db = AppDb(
        categories: const [],
        incomes: const [],
        allocations: const [],
        expenses: const [
          Expense(id: 'e1', date: '2026-01-03', amount: 20, sourceType: 'subscription'),
        ],
      );
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('a subscription dueDay out of 1-31 is rejected', () {
      final db = AppDb.empty.copyWithSubscriptions([
        const Subscription(id: 's1', name: 'Netflix', amount: 39.9, dueDay: 32, createdAt: '2026-01-01'),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('an installment purchase with chargedInstallments > installments is rejected', () {
      final db = AppDb.empty.copyWithInstallments([
        const InstallmentPurchase(
          id: 'p1',
          name: 'Notebook',
          totalAmount: 1200,
          installments: 12,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-02-01',
          createdAt: '2026-01-01',
          chargedInstallments: 13,
        ),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('an installment purchase with amortizedAmount above totalAmount is rejected', () {
      final db = AppDb.empty.copyWithInstallments([
        const InstallmentPurchase(
          id: 'p1',
          name: 'Notebook',
          totalAmount: 100,
          installments: 2,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-02-01',
          createdAt: '2026-01-01',
          amortizedAmount: 150,
        ),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });

    test('a dueDayOverride out of 1-31 is rejected', () {
      final db = AppDb.empty.copyWithInstallments([
        const InstallmentPurchase(
          id: 'p1',
          name: 'Notebook',
          totalAmount: 100,
          installments: 2,
          purchaseDate: '2026-01-01',
          firstChargeDate: '2026-02-01',
          createdAt: '2026-01-01',
          dueDayOverride: 0,
        ),
      ]);
      expect(() => validateBackupShape(db), throwsA(isA<BackupShapeError>()));
    });
  });
}

extension _AppDbTestHelpers on AppDb {
  AppDb copyWithCategories(List<Category> categories) => AppDb(
    categories: categories,
    incomes: incomes,
    allocations: allocations,
    expenses: expenses,
    subscriptions: subscriptions,
    installmentPurchases: installmentPurchases,
  );

  AppDb copyWithSubscriptions(List<Subscription> subscriptions) => AppDb(
    categories: categories,
    incomes: incomes,
    allocations: allocations,
    expenses: expenses,
    subscriptions: subscriptions,
    installmentPurchases: installmentPurchases,
  );

  AppDb copyWithInstallments(List<InstallmentPurchase> installmentPurchases) => AppDb(
    categories: categories,
    incomes: incomes,
    allocations: allocations,
    expenses: expenses,
    subscriptions: subscriptions,
    installmentPurchases: installmentPurchases,
  );
}
