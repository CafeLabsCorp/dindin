/// What a caixinha is for. Drives which visualization/fields the UI offers:
/// a spending envelope gets a monthly budget bar; a savings box gets a goal
/// progress bar (or the month's net inflow when no goal is set).
enum CategoryKind {
  spend('spend'),
  save('save');

  final String value;
  const CategoryKind(this.value);

  static CategoryKind? fromValue(String? v) => switch (v) {
    'spend' => CategoryKind.spend,
    'save' => CategoryKind.save,
    _ => null,
  };
}

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

  /// What this caixinha is for: [CategoryKind.spend] (envelope de gasto — the
  /// monthly-budget bar applies) or [CategoryKind.save] (cofrinho de guardar —
  /// the savings goal applies). Stored as the strings 'spend'/'save'. `null`
  /// means the doc predates this field; legacy docs behave as [spend], which
  /// is the only semantics that existed before.
  final CategoryKind? kind;

  /// Optional savings goal for a [CategoryKind.save] caixinha, in BRL: the
  /// total amount the user wants to accumulate ("juntar R$ 5.000"). `null`
  /// means no goal set. Ignored for spending caixinhas.
  final double? goalAmount;

  /// Whether this caixinha is allowed to hold a negative balance — a "dívida"
  /// of the caixinha that the next allocation/transfer-in pays down before
  /// building positive balance again (this is plain arithmetic on the running
  /// balance, not a separate mechanism). Only meaningful for
  /// [CategoryKind.spend]; a [CategoryKind.save] caixinha is ALWAYS
  /// non-negative regardless of this flag. `null`/absent (a doc predating this
  /// field) behaves as `false` — the only semantics that existed before.
  ///
  /// Turning it OFF while the balance is negative is allowed and FREEZES the
  /// existing debt; while off and negative the caixinha refuses further
  /// spends/withdrawals until an allocation/transfer brings it back to >= 0.
  /// The server-side gate for all of this lives in `firestore.rules`
  /// (`catAllowsNeg` + `catDeltaOk`); [allowsNegativeBalance] mirrors it for
  /// the client's pre-write check.
  final bool? allowNegative;

  const Category({
    required this.id,
    required this.name,
    required this.recurring,
    required this.createdAt,
    this.monthlyBudget,
    this.kind,
    this.goalAmount,
    this.allowNegative,
  });

  /// Effective purpose: legacy docs (null [kind]) behave as spending
  /// envelopes, preserving the only semantics that existed before the field.
  CategoryKind get effectiveKind => kind ?? CategoryKind.spend;

  /// Whether a spend/withdrawal may currently push this caixinha (further)
  /// negative. Mirrors `catAllowsNeg` in `firestore.rules`: the toggle must be
  /// on AND the caixinha must be a spend envelope. A `save` caixinha is never
  /// eligible. Legacy docs (null [allowNegative]) resolve to `false`.
  bool get allowsNegativeBalance =>
      (allowNegative ?? false) && effectiveKind == CategoryKind.spend;

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] as String,
      recurring: map['recurring'] as bool,
      createdAt: map['createdAt'] as String,
      monthlyBudget: (map['monthlyBudget'] as num?)?.toDouble(),
      kind: CategoryKind.fromValue(map['kind'] as String?),
      goalAmount: (map['goalAmount'] as num?)?.toDouble(),
      allowNegative: map['allowNegative'] as bool?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'recurring': recurring,
      'createdAt': createdAt,
      if (monthlyBudget != null) 'monthlyBudget': monthlyBudget,
      if (kind != null) 'kind': kind!.value,
      if (goalAmount != null) 'goalAmount': goalAmount,
      if (allowNegative != null) 'allowNegative': allowNegative,
    };
  }

  Category copyWith({
    String? name,
    bool? recurring,
    double? monthlyBudget,
    CategoryKind? kind,
    double? goalAmount,
    bool? allowNegative,
  }) {
    return Category(
      id: id,
      name: name ?? this.name,
      recurring: recurring ?? this.recurring,
      createdAt: createdAt,
      monthlyBudget: monthlyBudget ?? this.monthlyBudget,
      kind: kind ?? this.kind,
      goalAmount: goalAmount ?? this.goalAmount,
      allowNegative: allowNegative ?? this.allowNegative,
    );
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
