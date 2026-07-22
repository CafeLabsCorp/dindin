// Unit tests for Subscription's fromMap/toMap round-trip — mirrors
// test/models/category_test.dart's approach for a similarly simple model.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/subscription.dart';

void main() {
  group('Subscription', () {
    test('fromMap/toMap round-trip preserves every field', () {
      const sub = Subscription(
        id: 's1',
        name: 'Netflix',
        amount: 39.9,
        dueDay: 5,
        createdAt: '2026-01-01',
        lastChargedDate: '2026-02-05',
      );
      final map = sub.toMap();
      final roundTripped = Subscription.fromMap('s1', map);
      expect(roundTripped.name, 'Netflix');
      expect(roundTripped.amount, 39.9);
      expect(roundTripped.dueDay, 5);
      expect(roundTripped.createdAt, '2026-01-01');
      expect(roundTripped.lastChargedDate, '2026-02-05');
    });

    test('toMap omits lastChargedDate entirely when null (never charged yet)', () {
      const sub = Subscription(id: 's1', name: 'Netflix', amount: 39.9, dueDay: 5, createdAt: '2026-01-01');
      expect(sub.toMap().containsKey('lastChargedDate'), isFalse);
    });

    test('fromMap defaults lastChargedDate to null when absent', () {
      final sub = Subscription.fromMap('s1', {
        'name': 'Netflix',
        'amount': 39.9,
        'dueDay': 5,
        'createdAt': '2026-01-01',
      });
      expect(sub.lastChargedDate, isNull);
    });

    test('fromJson/toJson round-trip includes the id', () {
      const sub = Subscription(id: 's1', name: 'Netflix', amount: 39.9, dueDay: 5, createdAt: '2026-01-01');
      final json = sub.toJson();
      expect(json['id'], 's1');
      final restored = Subscription.fromJson(json);
      expect(restored.id, 's1');
      expect(restored.name, 'Netflix');
    });
  });
}
