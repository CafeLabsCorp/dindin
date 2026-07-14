/// Mirrors `CategorySchema` in the Next.js app's `src/lib/schemas.ts`.
class Category {
  final String id;
  final String name;
  final bool recurring;
  final String createdAt; // ISO date string (YYYY-MM-DD)

  /// Optional monthly spending limit for this caixinha, in BRL. `null` means
  /// "no limit set". This is a soft budget for reporting/warnings — it does
  /// NOT gate the hard money-integrity invariants (which are about allocated
  /// vs. spent, enforced server-side). Added as a nullable field so existing
  /// category documents and old JSON backups (which lack it) stay valid.
  ///
  /// Rationale for a new field instead of reusing `recurring`: a budget is a
  /// monetary amount (a number), whereas `recurring` is a boolean flag; they
  /// answer different questions and can't share storage without losing
  /// information. `recurring` is left untouched.
  final double? monthlyBudget;

  const Category({
    required this.id,
    required this.name,
    required this.recurring,
    required this.createdAt,
    this.monthlyBudget,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] as String,
      recurring: map['recurring'] as bool,
      createdAt: map['createdAt'] as String,
      monthlyBudget: (map['monthlyBudget'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'recurring': recurring,
      'createdAt': createdAt,
      if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
    };
  }

  Category copyWith({String? name, bool? recurring, double? monthlyBudget}) {
    return Category(
      id: id,
      name: name ?? this.name,
      recurring: recurring ?? this.recurring,
      createdAt: createdAt,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
