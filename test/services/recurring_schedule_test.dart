// Unit tests for the pure recurring-charge math shared by
// FirestoreService's catch-up (which bills each due occurrence) and the
// Gastos screen (which shows what is still pending). These functions have no
// Firestore dependency at all, so they're tested directly here; the tests in
// firestore_service_test.dart cover what catch-up DOES with the answers.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/installment_purchase.dart';
import 'package:dindin/models/subscription.dart';
import 'package:dindin/services/recurring_schedule.dart';

void main() {
  group('dueDateFor', () {
    test('keeps a day that exists in the month', () {
      expect(dueDateFor(2026, 1, 15), DateTime(2026, 1, 15));
    });

    test('clamps day 31 to the last day of a shorter month', () {
      expect(dueDateFor(2026, 2, 31), DateTime(2026, 2, 28));
      expect(dueDateFor(2026, 4, 31), DateTime(2026, 4, 30));
    });

    test('clamps to Feb 29 in a leap year', () {
      expect(dueDateFor(2028, 2, 31), DateTime(2028, 2, 29));
    });
  });

  group('isoDate', () {
    test('zero-pads month and day', () {
      expect(isoDate(DateTime(2026, 3, 7)), '2026-03-07');
    });
  });

  group('pendingDueDates', () {
    test('is empty before the first due date arrives', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 20,
        createdAt: '2026-01-01',
      );
      expect(pendingDueDates(sub, DateTime(2026, 1, 19)), isEmpty);
    });

    test('includes a due date landing exactly today', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 20,
        createdAt: '2026-01-01',
      );
      expect(pendingDueDates(sub, DateTime(2026, 1, 20)), [DateTime(2026, 1, 20)]);
    });

    test('lists every missed month oldest first when never charged', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 10,
        createdAt: '2025-11-01',
      );
      expect(pendingDueDates(sub, DateTime(2026, 1, 15)), [
        DateTime(2025, 11, 10),
        DateTime(2025, 12, 10),
        DateTime(2026, 1, 10),
      ]);
    });

    test('resumes from the month after lastChargedDate', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 10,
        createdAt: '2025-11-01',
        lastChargedDate: '2025-12-10',
      );
      expect(pendingDueDates(sub, DateTime(2026, 1, 15)), [DateTime(2026, 1, 10)]);
    });

    test('is empty once the current month is already charged', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 10,
        createdAt: '2025-11-01',
        lastChargedDate: '2026-01-10',
      );
      expect(pendingDueDates(sub, DateTime(2026, 1, 15)), isEmpty);
    });

    test('never backdates a charge to before the subscription existed', () {
      // Registered Jan 20th with due day 5: January's occurrence already
      // passed when it was created and must not be billed retroactively.
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 40,
        dueDay: 5,
        createdAt: '2026-01-20',
      );
      expect(pendingDueDates(sub, DateTime(2026, 2, 10)), [DateTime(2026, 2, 5)]);
    });

    test('clamps a dueDay-31 subscription per month', () {
      const sub = Subscription(
        id: 's1',
        name: 'Aluguel',
        amount: 40,
        dueDay: 31,
        createdAt: '2026-01-01',
      );
      expect(pendingDueDates(sub, DateTime(2026, 3, 1)), [
        DateTime(2026, 1, 31),
        DateTime(2026, 2, 28),
      ]);
    });
  });

  group('installmentAmounts', () {
    test('splits evenly when the total divides cleanly', () {
      expect(installmentAmounts(300, 3), [100, 100, 100]);
    });

    test('puts the rounding remainder on the LAST installment', () {
      final amounts = installmentAmounts(100, 3);
      expect(amounts, [33.33, 33.33, 33.34]);
    });

    test('slices always sum back to exactly the total', () {
      for (final total in [100.0, 999.99, 1234.56, 0.03]) {
        for (final n in [2, 3, 7, 12, 36]) {
          final sum = installmentAmounts(total, n).reduce((a, b) => a + b);
          expect((sum - total).abs() < 0.005, isTrue, reason: '$total in ${n}x summed to $sum');
        }
      }
    });
  });

  group('installmentDueDate', () {
    const purchase = InstallmentPurchase(
      id: 'p1',
      name: 'Notebook',
      totalAmount: 1200,
      installments: 12,
      purchaseDate: '2026-01-01',
      firstChargeDate: '2026-01-31',
      createdAt: '2026-01-01',
    );

    test('anchors on firstChargeDate for index 0', () {
      expect(installmentDueDate(purchase, 0), DateTime(2026, 1, 31));
    });

    test('advances one month per index, clamping short months', () {
      expect(installmentDueDate(purchase, 1), DateTime(2026, 2, 28));
      expect(installmentDueDate(purchase, 2), DateTime(2026, 3, 31));
    });
  });

  group('pendingInstallmentIndexes', () {
    InstallmentPurchase purchase({int charged = 0}) => InstallmentPurchase(
      id: 'p1',
      name: 'Notebook',
      totalAmount: 300,
      installments: 3,
      purchaseDate: '2026-01-01',
      firstChargeDate: '2026-01-10',
      createdAt: '2026-01-01',
      chargedInstallments: charged,
    );

    test('lists every installment already due, oldest first', () {
      expect(pendingInstallmentIndexes(purchase(), DateTime(2026, 3, 15)), [0, 1, 2]);
    });

    test('stops at installments not yet due', () {
      expect(pendingInstallmentIndexes(purchase(), DateTime(2026, 2, 15)), [0, 1]);
    });

    test('resumes from chargedInstallments', () {
      expect(pendingInstallmentIndexes(purchase(charged: 2), DateTime(2026, 3, 15)), [2]);
    });

    test('is empty once fully charged — never runs past the last installment', () {
      expect(pendingInstallmentIndexes(purchase(charged: 3), DateTime(2027, 1, 1)), isEmpty);
    });
  });
}
