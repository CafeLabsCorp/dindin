/// Mirrors `ExpenseSchema` in the Next.js app's `src/lib/schemas.ts`.
class Expense {
  final String id;
  final String date; // ISO date string (YYYY-MM-DD)
  final double amount;
  final String categoryId;
  final String? description;

  const Expense({
    required this.id,
    required this.date,
    required this.amount,
    required this.categoryId,
    this.description,
  });

  factory Expense.fromMap(String id, Map<String, dynamic> map) {
    return Expense(
      id: id,
      date: map['date'] as String,
      amount: (map['amount'] as num).toDouble(),
      categoryId: map['categoryId'] as String,
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'amount': amount,
      'categoryId': categoryId,
      if (description != null) 'description': description,
    };
  }

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
