// Unit tests for `Category.allowsNegativeBalance` — the client's mirror of
// `catAllowsNeg` in firestore.rules. Pure logic, no I/O, so it's tested
// directly here rather than only indirectly through FirestoreService.
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/models/category.dart';

void main() {
  group('Category.allowsNegativeBalance', () {
    test('true when allowNegative is true and kind is spend', () {
      const cat = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      expect(cat.allowsNegativeBalance, isTrue);
    });

    test('false when allowNegative is true but kind is save', () {
      const cat = Category(
        id: 'c1',
        name: 'Reserva',
        recurring: false,
        createdAt: '2026-01-01',
        kind: CategoryKind.save,
        allowNegative: true,
      );
      expect(cat.allowsNegativeBalance, isFalse);
    });

    test('false when allowNegative is false, regardless of kind', () {
      const spend = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: false,
      );
      expect(spend.allowsNegativeBalance, isFalse);
    });

    test('false when allowNegative is null/absent (legacy doc default)', () {
      const legacy = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
      );
      expect(legacy.allowNegative, isNull);
      expect(legacy.allowsNegativeBalance, isFalse);
    });

    test('true when kind is null (legacy doc, no explicit kind) and allowNegative is true', () {
      // A legacy doc with no `kind` behaves as `spend` per effectiveKind, so
      // this resolves to TRUE — regression guard for that legacy-defaulting
      // behavior specifically (kind absence must NOT be treated as "save").
      const legacy = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        allowNegative: true,
      );
      expect(legacy.effectiveKind, CategoryKind.spend);
      expect(legacy.allowsNegativeBalance, isTrue);
    });

    test('fromMap/toMap round-trip preserves allowNegative', () {
      const cat = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: true,
      );
      final map = cat.toMap();
      expect(map['allowNegative'], true);
      final roundTripped = Category.fromMap('c1', map);
      expect(roundTripped.allowNegative, true);
      expect(roundTripped.allowsNegativeBalance, isTrue);
    });

    test('toMap omits allowNegative entirely when null (does not write `false` for legacy docs)', () {
      const cat = Category(id: 'c1', name: 'Lazer', recurring: false, createdAt: '2026-01-01');
      expect(cat.toMap().containsKey('allowNegative'), isFalse);
    });

    test('copyWith can flip allowNegative independently of other fields', () {
      const cat = Category(
        id: 'c1',
        name: 'Lazer',
        recurring: false,
        createdAt: '2026-01-01',
        kind: CategoryKind.spend,
        allowNegative: false,
      );
      final updated = cat.copyWith(allowNegative: true);
      expect(updated.allowNegative, isTrue);
      expect(updated.name, cat.name); // unrelated fields untouched
    });
  });
}
