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

/// Formats an amount the same way the create/edit forms parse it back
/// (`double.tryParse(text.replaceAll(',', '.'))`), so pre-filling an edit
/// form's amount field round-trips exactly.
String formatAmountInput(num value) {
  return value.toStringAsFixed(2).replaceAll('.', ',');
}
