import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import 'package:dindin/utils/format.dart';

void main() {
  group('formatDate follows the app language', () {
    setUpAll(() => initializeDateFormatting('pt_BR'));
    tearDown(() => Intl.defaultLocale = null);

    test('Portuguese (and the default): dd/MM/yyyy', () {
      expect(formatDate('2026-11-12'), '12/11/2026');
      Intl.defaultLocale = 'pt';
      expect(formatDate('2026-11-12'), '12/11/2026');
    });

    test('English: month first', () {
      Intl.defaultLocale = 'en';
      expect(formatDate('2026-11-12'), '11/12/2026');
    });
  });

  group('formatAmountInput / parseAmountInput (masked amount fields)', () {
    test('formatAmountInput groups thousands the way MoneyInputFormatter displays them', () {
      expect(formatAmountInput(80), '80,00');
      expect(formatAmountInput(1234.5), '1.234,50');
      expect(formatAmountInput(1234567.89), '1.234.567,89');
    });

    test('parseAmountInput strips thousands dots and reads the decimal comma', () {
      expect(parseAmountInput('80,00'), 80.0);
      expect(parseAmountInput('1.234,50'), 1234.5);
      expect(parseAmountInput('1.234.567,89'), 1234567.89);
    });

    test('formatAmountInput and parseAmountInput round-trip for values pre-filling an edit form', () {
      for (final value in [0.5, 80.0, 999.99, 1000.0, 1234.56, 1234567.89]) {
        expect(parseAmountInput(formatAmountInput(value)), value);
      }
    });

    test('parseAmountInput returns null for empty or invalid text', () {
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('  '), isNull);
      expect(parseAmountInput('abc'), isNull);
    });
  });
}
