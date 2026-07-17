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
}
