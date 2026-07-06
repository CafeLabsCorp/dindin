import 'income_source.dart';

/// Mirrors `IncomeSchema` in the Next.js app's `src/lib/schemas.ts`.
class Income {
  final String id;
  final String date; // ISO date string (YYYY-MM-DD)
  final double amount;
  final IncomeSource source;
  final String? description;

  const Income({
    required this.id,
    required this.date,
    required this.amount,
    required this.source,
    this.description,
  });

  factory Income.fromMap(String id, Map<String, dynamic> map) {
    return Income(
      id: id,
      date: map['date'] as String,
      amount: (map['amount'] as num).toDouble(),
      source: IncomeSource.fromValue(map['source'] as String),
      description: map['description'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'amount': amount,
      'source': source.value,
      if (description != null) 'description': description,
    };
  }

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
