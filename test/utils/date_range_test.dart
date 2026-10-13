import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/utils/date_range.dart';

void main() {
  group('isDateWithinRange', () {
    test('sem filtro (from e to nulos), tudo passa', () {
      expect(isDateWithinRange('2026-05-10', null, null), isTrue);
    });

    test('respeita o limite inferior (from)', () {
      final from = DateTime(2026, 5, 10);
      expect(isDateWithinRange('2026-05-09', from, null), isFalse);
      expect(isDateWithinRange('2026-05-10', from, null), isTrue); // inclusivo
      expect(isDateWithinRange('2026-05-11', from, null), isTrue);
    });

    test('respeita o limite superior (to)', () {
      final to = DateTime(2026, 5, 10);
      expect(isDateWithinRange('2026-05-11', null, to), isFalse);
      expect(isDateWithinRange('2026-05-10', null, to), isTrue); // inclusivo
      expect(isDateWithinRange('2026-05-09', null, to), isTrue);
    });

    test('intervalo fechado (from e to)', () {
      final from = DateTime(2026, 5, 1);
      final to = DateTime(2026, 5, 31);
      expect(isDateWithinRange('2026-04-30', from, to), isFalse);
      expect(isDateWithinRange('2026-05-15', from, to), isTrue);
      expect(isDateWithinRange('2026-06-01', from, to), isFalse);
    });
  });

  group(
    'rangeAfterPickingFrom / rangeAfterPickingTo (intervalo nunca fica invertido)',
    () {
      final may5 = DateTime(2026, 5, 5);
      final may24 = DateTime(2026, 5, 24);

      test('"De" depois do "Até" arrasta o "Até" pro mesmo dia', () {
        final r = rangeAfterPickingFrom(may24, may5);
        expect(r.from, may24);
        expect(r.to, may24);
      });

      test('"De" antes do "Até" não mexe no "Até"', () {
        final r = rangeAfterPickingFrom(may5, may24);
        expect(r.from, may5);
        expect(r.to, may24);
      });

      test('"Até" antes do "De" arrasta o "De" pro mesmo dia', () {
        final r = rangeAfterPickingTo(may5, may24);
        expect(r.from, may5);
        expect(r.to, may5);
      });

      test('sem o outro lado definido, só guarda o escolhido', () {
        expect(rangeAfterPickingFrom(may5, null).to, isNull);
        expect(rangeAfterPickingTo(may5, null).from, isNull);
      });

      test('mesmo dia nos dois lados é intervalo válido', () {
        final r = rangeAfterPickingFrom(may5, may5);
        expect((r.from, r.to), (may5, may5));
      });
    },
  );
}
