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

  /// Whether this caixinha is an ongoing thing rather than a one-off. On its
  /// own this is purely a display label ("Recorrente"/"Pontual" in
  /// Categorias) with no effect on any calculation — EXCEPT for a
  /// [CategoryKind.save] caixinha that also has [goalAmount] set, where it
  /// flips what the goal means: see [hasMonthlyGoal].
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

  /// Optional savings goal for a [CategoryKind.save] caixinha, in BRL. `null`
  /// means no goal set. Ignored for spending caixinhas. What it MEANS depends
  /// on [recurring] (see [hasMonthlyGoal]):
  ///
  ///  - [recurring] `false` (the original, still-default behavior): a
  ///    lifetime target — "juntar R$ 5.000 pra viagem" — tracked against the
  ///    caixinha's all-time running balance. Keeps growing toward the goal
  ///    forever; nothing about it resets.
  ///  - [recurring] `true`: a MONTHLY target — "guardar R$ 800 todo mês pro
  ///    casamento" — tracked against `savedThisMonthByCategory` instead
  ///    (`aggregation_service.dart`), so progress starts back at zero every
  ///    calendar month with no action needed (that function already sums
  ///    only the current month's allocations/expenses; there's no counter
  ///    that gets explicitly "reset"). The caixinha's all-time balance is
  ///    untouched by this and keeps showing separately as its running total.
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

  /// Whether [goalAmount] should be read as a MONTHLY target (resets every
  /// calendar month, tracked against this month's net saved) rather than a
  /// lifetime one (tracked against the all-time balance) — see [goalAmount]'s
  /// doc for the full explanation. `false` for a caixinha with no goal at
  /// all, or a [CategoryKind.spend] one (`recurring` there is still just the
  /// display label, unrelated to this).
  bool get hasMonthlyGoal => effectiveKind == CategoryKind.save && recurring && goalAmount != null;

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
