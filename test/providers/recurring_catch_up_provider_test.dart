// The recurring-charge catch-up runs subscriptions and installment purchases
// independently: a failure in one must not skip the other.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:dindin/providers/providers.dart';
import 'package:dindin/services/firestore_service.dart';

class _MockFirestoreService extends Mock implements FirestoreService {}

void main() {
  test('uma falha nas assinaturas não impede o catch-up dos parcelamentos, e o erro continua visível', () async {
    final firestore = _MockFirestoreService();
    when(() => firestore.catchUpSubscriptions()).thenThrow(StateError('boom'));
    when(() => firestore.catchUpInstallmentPurchases())
        .thenAnswer((_) async => const RecurringChargeReport(count: 1, total: 33.34));
    final container = ProviderContainer(
      overrides: [firestoreServiceProvider.overrideWithValue(firestore)],
    );
    addTearDown(container.dispose);

    await expectLater(container.read(recurringChargesCatchUpProvider.future), throwsA(isA<StateError>()));

    verify(() => firestore.catchUpInstallmentPurchases()).called(1);
    expect(container.read(recurringChargesCatchUpProvider).hasError, isTrue);
  });

  test('sem falha, soma os dois relatórios', () async {
    final firestore = _MockFirestoreService();
    when(() => firestore.catchUpSubscriptions())
        .thenAnswer((_) async => const RecurringChargeReport(count: 1, total: 40));
    when(() => firestore.catchUpInstallmentPurchases())
        .thenAnswer((_) async => const RecurringChargeReport(count: 2, total: 66.68));
    final container = ProviderContainer(
      overrides: [firestoreServiceProvider.overrideWithValue(firestore)],
    );
    addTearDown(container.dispose);

    final report = await container.read(recurringChargesCatchUpProvider.future);

    expect(report.count, 3);
    expect(report.total, 106.68);
  });
}
