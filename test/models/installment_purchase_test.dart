// Unit tests for InstallmentPurchase's fromMap/toMap round-trip — mirrors
// test/models/subscription_test.dart's approach for a similarly simple model.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/installment_purchase.dart';

void main() {
  group('InstallmentPurchase', () {
    test('fromMap/toMap round-trip preserves every field', () {
      const purchase = InstallmentPurchase(
        id: 'p1',
        name: 'Notebook Dell',
        totalAmount: 300,
        installments: 3,
        purchaseDate: '2026-01-10',
        firstChargeDate: '2026-02-05',
        createdAt: '2026-01-10',
        chargedInstallments: 1,
      );
      final map = purchase.toMap();
      final roundTripped = InstallmentPurchase.fromMap('p1', map);
      expect(roundTripped.name, 'Notebook Dell');
      expect(roundTripped.totalAmount, 300);
      expect(roundTripped.installments, 3);
      expect(roundTripped.purchaseDate, '2026-01-10');
      expect(roundTripped.firstChargeDate, '2026-02-05');
      expect(roundTripped.createdAt, '2026-01-10');
      expect(roundTripped.chargedInstallments, 1);
    });

    test('fromMap defaults chargedInstallments to 0 when absent', () {
      final purchase = InstallmentPurchase.fromMap('p1', {
        'name': 'Notebook Dell',
        'totalAmount': 300,
        'installments': 3,
        'purchaseDate': '2026-01-10',
        'firstChargeDate': '2026-02-05',
        'createdAt': '2026-01-10',
      });
      expect(purchase.chargedInstallments, 0);
    });

    test('isFullyCharged is true once chargedInstallments reaches installments', () {
      const notDone = InstallmentPurchase(
        id: 'p1',
        name: 'Notebook Dell',
        totalAmount: 300,
        installments: 3,
        purchaseDate: '2026-01-10',
        firstChargeDate: '2026-02-05',
        createdAt: '2026-01-10',
        chargedInstallments: 2,
      );
      const done = InstallmentPurchase(
        id: 'p1',
        name: 'Notebook Dell',
        totalAmount: 300,
        installments: 3,
        purchaseDate: '2026-01-10',
        firstChargeDate: '2026-02-05',
        createdAt: '2026-01-10',
        chargedInstallments: 3,
      );
      expect(notDone.isFullyCharged, isFalse);
      expect(done.isFullyCharged, isTrue);
    });

    test('fromJson/toJson round-trip includes the id', () {
      const purchase = InstallmentPurchase(
        id: 'p1',
        name: 'Notebook Dell',
        totalAmount: 300,
        installments: 3,
        purchaseDate: '2026-01-10',
        firstChargeDate: '2026-02-05',
        createdAt: '2026-01-10',
      );
      final json = purchase.toJson();
      expect(json['id'], 'p1');
      final restored = InstallmentPurchase.fromJson(json);
      expect(restored.id, 'p1');
      expect(restored.name, 'Notebook Dell');
    });
  });
}
