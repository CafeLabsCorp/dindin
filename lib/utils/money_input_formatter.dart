import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Digit-push money mask: every keystroke is another digit of CENTS pushed
/// in from the right (calculator/ATM style) — typing "1", "2", "3" in
/// sequence shows "0,01" -> "0,12" -> "1,23". The user never types a decimal
/// separator; backspace removes the rightmost digit. Always reformats from
/// scratch and pins the cursor to the end — a money field's digits only ever
/// grow from the right, so there's no meaningful "middle" to place a cursor
/// in.
///
/// Grouping always follows the pt-BR convention (dot thousands, comma
/// decimals), matching `formatCurrency`/`formatAmountInput` in `format.dart`
/// — money in this app is always Reais, so its punctuation doesn't change
/// with the interface language.
class MoneyInputFormatter extends TextInputFormatter {
  static final _nonDigits = RegExp(r'[^0-9]');
  static final _grouped = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(_nonDigits, '');
    if (digits.isEmpty) {
      return const TextEditingValue(text: '');
    }
    final formatted = _grouped.format(int.parse(digits) / 100).trim();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
