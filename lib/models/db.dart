import 'allocation.dart';
import 'category.dart';
import 'expense.dart';
import 'income.dart';
import 'installment_purchase.dart';
import 'subscription.dart';

/// Mirrors `DbSchema` / `Db` in the Next.js app's `src/lib/schemas.ts` — the
/// full snapshot shape used for JSON import/export (`data/db.json`).
class AppDb {
  final List<Category> categories;
  final List<Income> incomes;
  final List<Allocation> allocations;
  final List<Expense> expenses;

  /// Added after the original four-collection schema — defaults to `const
  /// []` (rather than `required`) so every pre-existing call site and old
  /// JSON backup (which has no `subscriptions` key at all) keeps compiling
  /// and importing unchanged, matching how `Category.monthlyBudget` and
  /// `Allocation.transferId` were added additively.
  final List<Subscription> subscriptions;

  /// Same additive treatment as [subscriptions] — a bounded recurring charge
  /// (a card purchase split into N monthly installments) instead of an
  /// open-ended one.
  final List<InstallmentPurchase> installmentPurchases;

  const AppDb({
    required this.categories,
    required this.incomes,
    required this.allocations,
    required this.expenses,
    this.subscriptions = const [],
    this.installmentPurchases = const [],
  });

  static const empty = AppDb(
    categories: [],
    incomes: [],
    allocations: [],
    expenses: [],
    subscriptions: [],
    installmentPurchases: [],
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
      subscriptions: (json['subscriptions'] as List?)
              ?.map((e) => Subscription.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      installmentPurchases: (json['installmentPurchases'] as List?)
              ?.map((e) => InstallmentPurchase.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toJson() => {
    'categories': categories.map((e) => e.toJson()).toList(),
    'incomes': incomes.map((e) => e.toJson()).toList(),
    'allocations': allocations.map((e) => e.toJson()).toList(),
    'expenses': expenses.map((e) => e.toJson()).toList(),
    'subscriptions': subscriptions.map((e) => e.toJson()).toList(),
    'installmentPurchases': installmentPurchases.map((e) => e.toJson()).toList(),
  };
}
