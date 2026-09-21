import 'package:intl/intl.dart';

/// Ported 1:1 from the Next.js app's `src/lib/format.ts`.
String formatCurrency(num value) {
  return NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$').format(value);
}

String formatCurrencyCompact(num value) {
  return NumberFormat.currency(
    locale: 'pt_BR',
    symbol: 'R\$',
    decimalDigits: 0,
  ).format(value);
}

String formatMonthLabel(String month) {
  final parts = month.split('-');
  final date = DateTime(int.parse(parts[0]), int.parse(parts[1]));
  return DateFormat('MMM yyyy', 'pt_BR').format(date);
}

String todayIso() => isoDateFrom(DateTime.now());

/// Formats a [DateTime] as the app's ISO date string (`YYYY-MM-DD`), the
/// shape every ledger doc's `date` field uses. Centralized here (previously
/// duplicated as a private `todayIsoFrom` in `receitas_page.dart`, re-exported
/// into `gastos_page.dart`) so every screen/sheet that needs it — including
/// the new edit sheets and date-range filters — shares one implementation.
String isoDateFrom(DateTime date) {
  return '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

String formatDate(String iso) {
  final date = DateTime.parse(iso);
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
}

/// Formats an amount the way [MoneyInputFormatter] displays it once the
/// user finishes typing it — grouped thousands, comma decimals — so
/// pre-filling an edit form's masked amount field shows exactly what
/// continuing to edit it would produce.
String formatAmountInput(num value) {
  return NumberFormat.currency(
    locale: 'pt_BR',
    symbol: '',
    decimalDigits: 2,
  ).format(value).trim();
}

/// Parses text produced by a [MoneyInputFormatter]-masked field (grouped
/// thousands, comma decimals) back into a value — strips the thousands-
/// separator dots before swapping the decimal comma for a dot, so
/// `double.tryParse` can read it. Also reads a plain unmasked "1234,56" or
/// "1234.56" fine, since neither has a stray dot for the strip to disturb.
double? parseAmountInput(String text) {
  final normalized = text.trim().replaceAll('.', '').replaceAll(',', '.');
  return double.tryParse(normalized);
}
