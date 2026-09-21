import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dindin/utils/money_input_formatter.dart';

/// Feeds a sequence of raw keystrokes through the formatter the way a real
/// text field would: each call's `newValue` is the PREVIOUS formatted text
/// plus one more character appended, mirroring how typing actually grows a
/// field. Returns the displayed text after every keystroke.
List<String> _type(String keys) {
  final formatter = MoneyInputFormatter();
  var value = const TextEditingValue(text: '');
  final history = <String>[];
  for (final key in keys.split('')) {
    final next = TextEditingValue(text: value.text + key);
    value = formatter.formatEditUpdate(value, next);
    history.add(value.text);
  }
  return history;
}

void main() {
  group('MoneyInputFormatter', () {
    test('digit-pushes cents in from the right, no separator typed', () {
      expect(_type('123'), ['0,01', '0,12', '1,23']);
    });

    test('crosses into reais and groups thousands past 999,99', () {
      expect(_type('100000'), ['0,01', '0,10', '1,00', '10,00', '100,00', '1.000,00']);
    });

    test('backspace (empty the field, retype) drops back to the right amount', () {
      // A single call with a SHORTER newValue.text than oldValue simulates
      // backspace — the formatter only ever reformats from newValue.text, so
      // it doesn't matter that this wasn't reached via `_type`'s append-only
      // path.
      final formatter = MoneyInputFormatter();
      final afterTyping123 = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '0,12'),
      ); // pretend "12" was typed and is now displayed as "0,12"
      final afterBackspace = formatter.formatEditUpdate(
        afterTyping123,
        const TextEditingValue(text: '0,1'), // one character removed
      );
      expect(afterBackspace.text, '0,01');
    });

    test('clearing all digits empties the field instead of showing 0,00', () {
      final formatter = MoneyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: '1,23'),
        const TextEditingValue(text: ''),
      );
      expect(result.text, '');
    });

    test('cursor always lands at the end of the reformatted text', () {
      final formatter = MoneyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '5'),
      );
      expect(result.selection, TextSelection.collapsed(offset: result.text.length));
    });

    test('ignores any non-digit the platform keyboard might still deliver', () {
      // TextInputType.number can still hand formatters a decimal separator
      // on some platforms/locales — only the digits should count.
      final formatter = MoneyInputFormatter();
      final result = formatter.formatEditUpdate(
        const TextEditingValue(text: ''),
        const TextEditingValue(text: '1,,.23'),
      );
      expect(result.text, '1,23'); // digits "123" -> R$1,23
    });
  });
}
