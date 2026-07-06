import 'allocation.dart';
import 'category.dart';
import 'expense.dart';
import 'income.dart';

/// Mirrors `DbSchema` / `Db` in the Next.js app's `src/lib/schemas.ts` — the
/// full snapshot shape used for JSON import/export (`data/db.json`).
class AppDb {
  final List<Category> categories;
  final List<Income> incomes;
  final List<Allocation> allocations;
  final List<Expense> expenses;

  const AppDb({
    required this.categories,
    required this.incomes,
    required this.allocations,
    required this.expenses,
  });

  static const empty = AppDb(
    categories: [],
    incomes: [],
    allocations: [],
    expenses: [],
  );

  factory AppDb.fromJson(Map<String, dynamic> json) {
    return AppDb(
      categories: (json['categories'] as List)
          .map((e) => Category.fromJson(e as Map<String, dynamic>))
          .toList(),
      incomes: (json['incomes'] as List)
          .map((e) => Income.fromJson(e as Map<String, dynamic>))
          .toList(),
      allocations: (json['allocations'] as List)
          .map((e) => Allocation.fromJson(e as Map<String, dynamic>))
          .toList(),
      expenses: (json['expenses'] as List)
          .map((e) => Expense.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'categories': categories.map((e) => e.toJson()).toList(),
    'incomes': incomes.map((e) => e.toJson()).toList(),
    'allocations': allocations.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
  };
}
