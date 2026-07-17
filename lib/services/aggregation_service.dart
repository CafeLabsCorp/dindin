import '../models/db.dart';

/// Ported 1:1 from the Next.js app's `src/lib/aggregations.ts`.
String monthKey(String date) => date.substring(0, 7); // "YYYY-MM"

/// Summing many docs' `amount` accumulates binary floating-point error (e.g.
/// an account that is truly R$0 can sum to -1.7e-13). BRL only has cents, so
/// round every aggregated total to the cent before it reaches a comparison or
/// the screen — otherwise a mathematically-zero balance can display as
/// "-R$ 0,00".
double round2(double n) => (n * 100).round() / 100;

double totalIncome(AppDb db) => round2(db.incomes.fold(0.0, (sum, i) => sum + i.amount));

double totalAllocated(AppDb db) => round2(db.allocations.fold(0.0, (sum, a) => sum + a.amount));

/// Expenses charged straight against the account balance (no caixinha).
double accountExpenses(AppDb db) => round2(
  db.expenses.where((e) => e.categoryId == null).fold(0.0, (sum, e) => sum + e.amount),
);

/// Money that came in but hasn't been allocated to a caixinha or spent
/// directly — the general account balance.
double accountBalance(AppDb db) =>
    round2(totalIncome(db) - totalAllocated(db) - accountExpenses(db));

Map<String, double> categoryBalances(AppDb db) {
  final balances = <String, double>{for (final c in db.categories) c.id: 0};
  for (final a in db.allocations) {
    balances[a.categoryId] = (balances[a.categoryId] ?? 0) + a.amount;
  }
  for (final e in db.expenses) {
    final categoryId = e.categoryId;
    if (categoryId == null) continue;
    balances[categoryId] = (balances[categoryId] ?? 0) - e.amount;
  }
  return balances.map((id, v) => MapEntry(id, round2(v)));
}

/// Account balance plus every caixinha's balance — equal to
/// total income minus total expenses, however the money is split.
double totalBalance(AppDb db) {
  return round2(accountBalance(db) + categoryBalances(db).values.fold(0.0, (sum, v) => sum + v));
}

class MonthSummary {
  final String month; // "YYYY-MM"
  final double totalIncome;
  final double totalExpense;
  final double net;
  final Map<String, double> incomeBySource;
  final Map<String, double> expenseByCategory;

  const MonthSummary({
    required this.month,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
    required this.incomeBySource,
    required this.expenseByCategory,
  });
}

MonthSummary monthSummary(AppDb db, String month) {
  final incomes = db.incomes.where((i) => monthKey(i.date) == month);
  final expenses = db.expenses.where((e) => monthKey(e.date) == month);

  final incomeBySource = <String, double>{};
  for (final i in incomes) {
    incomeBySource[i.source.value] = (incomeBySource[i.source.value] ?? 0) + i.amount;
  }

  final expenseByCategory = <String, double>{};
  for (final e in expenses) {
    final categoryId = e.categoryId;
    if (categoryId == null) continue;
    expenseByCategory[categoryId] = (expenseByCategory[categoryId] ?? 0) + e.amount;
  }

  final totalIncome = round2(incomes.fold(0.0, (sum, i) => sum + i.amount));
  final totalExpense = round2(expenses.fold(0.0, (sum, e) => sum + e.amount));

  return MonthSummary(
    month: month,
    totalIncome: totalIncome,
    totalExpense: totalExpense,
    net: round2(totalIncome - totalExpense),
    incomeBySource: incomeBySource.map((k, v) => MapEntry(k, round2(v))),
    expenseByCategory: expenseByCategory.map((k, v) => MapEntry(k, round2(v))),
  );
}

List<String> allMonths(AppDb db) {
  final set = <String>{};
  for (final i in db.incomes) {
    set.add(monthKey(i.date));
  }
  for (final e in db.expenses) {
    set.add(monthKey(e.date));
  }
  final list = set.toList()..sort();
  return list;
}

List<MonthSummary> monthlyHistory(AppDb db) {
  return allMonths(db).map((m) => monthSummary(db, m)).toList();
}

String currentMonthKey() {
  final now = DateTime.now().toUtc();
  return '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}';
}

class Summary {
  final double total;
  final double accountBalance;
  final Map<String, double> balancesByCategory;
  final MonthSummary currentMonth;
  final List<MonthSummary> history;

  const Summary({
    required this.total,
    required this.accountBalance,
    required this.balancesByCategory,
    required this.currentMonth,
    required this.history,
  });
}

/// Mirrors the `/api/summary` route's response shape.
Summary buildSummary(AppDb db) {
  return Summary(
    total: totalBalance(db),
    accountBalance: accountBalance(db),
    balancesByCategory: categoryBalances(db),
    currentMonth: monthSummary(db, currentMonthKey()),
    history: monthlyHistory(db),
  );
}
