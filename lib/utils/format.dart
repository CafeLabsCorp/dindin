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

String todayIso() {
  final now = DateTime.now();
  return DateFormat('yyyy-MM-dd').format(now);
}

String formatDate(String iso) {
  final date = DateTime.parse(iso);
  return DateFormat('dd/MM/yyyy', 'pt_BR').format(date);
}
