/// A transfer of money from the general account balance into a caixinha
/// (category). Mirrors `AllocationSchema` in the Next.js app's
/// `src/lib/schemas.ts`, minus `incomeId` — allocations draw from the
/// pooled account balance, not from a specific income.
class Allocation {
  final String id;
  final String categoryId;
  final double amount;
  final String date; // ISO date string (YYYY-MM-DD)

  const Allocation({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
  });

  factory Allocation.fromMap(String id, Map<String, dynamic> map) {
    return Allocation(
      id: id,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {
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
