/// Mirrors `AllocationSchema` in the Next.js app's `src/lib/schemas.ts`.
class Allocation {
  final String id;
  final String incomeId;
  final String categoryId;
  final double amount;
  final String date; // ISO date string (YYYY-MM-DD)

  const Allocation({
    required this.id,
    required this.incomeId,
    required this.categoryId,
    required this.amount,
    required this.date,
  });

  factory Allocation.fromMap(String id, Map<String, dynamic> map) {
    return Allocation(
      id: id,
      incomeId: map['incomeId'] as String,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'incomeId': incomeId,
      'categoryId': categoryId,
      'amount': amount,
      'date': date,
    };
  }

  factory Allocation.fromJson(Map<String, dynamic> json) {
    return Allocation.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
