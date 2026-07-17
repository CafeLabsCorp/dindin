import 'format.dart';

/// Whether an ISO `YYYY-MM-DD` date string falls within an inclusive
/// [from]/[to] range. Either bound may be null (an open end). ISO date
/// strings sort lexicographically the same as chronologically, so this is a
/// plain string comparison — no `DateTime` parsing needed.
///
/// Extracted as a standalone, easily-unit-testable function (`docs/DESIGN.md`
/// §5.4) rather than inlined in each page's build method, since it's the same
/// rule for Receitas and Gastos.
bool isDateWithinRange(String isoDate, DateTime? from, DateTime? to) {
  if (from != null && isoDate.compareTo(isoDateFrom(from)) < 0) return false;
  if (to != null && isoDate.compareTo(isoDateFrom(to)) > 0) return false;
  return true;
}
