import 'income_source.dart';

/// Mirrors `IncomeSchema` in the Next.js app's `src/lib/schemas.ts`.
class Income {
  final String id;
  final String date; // ISO date string (YYYY-MM-DD)
  final double amount;
  final IncomeSource source;
  final String? description;

  /// When this doc was actually created, as a full ISO-8601 timestamp — set
  /// once at creation, never touched by an edit. [date] is the day the user
  /// says the money came in (freely editable, can be backdated); this is
  /// only a tiebreaker for sorting same-[date] entries in the order they
  /// were really entered (see `FirestoreService`'s ledger `watch*` methods).
  /// Nullable because a doc written before this field existed has none —
  /// those just fall back to Firestore's own (unspecified) order among ties.
  final String? createdAt;

  const Income({
    required this.id,
    required this.date,
    required this.amount,
    required this.source,
    this.description,
    this.createdAt,
  });

  factory Income.fromMap(String id, Map<String, dynamic> map) {
    return Income(
      id: id,
      date: map['date'] as String,
      amount: (map['amount'] as num).toDouble(),
      source: IncomeSource.fromValue(map['source'] as String),
      description: map['description'] as String?,
      createdAt: map['createdAt'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'amount': amount,
      'source': source.value,
      if (description != null) 'description': description,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
