/// A card purchase split into fixed monthly installments (e.g. "Notebook Dell,
/// R$ 1.200 em 12x"): the total amount is charged in equal monthly slices —
/// see `recurring_schedule.installmentAmounts` for the exact split, which
/// spreads any rounding remainder over the FIRST installments, a cent each
/// (matches a real card bill) —
/// out of the account balance by default, or out of a caixinha when
/// [categoryId] says so, same as a [Subscription].
///
/// Unlike a [Subscription], this is bounded: it stops generating charges once
/// [chargedInstallments] reaches [installments]. [chargedInstallments] tracks
/// how many installments have already been turned into an [Expense] by
/// `FirestoreService.catchUpInstallmentPurchases`, so catch-up never
/// double-charges or re-charges a finished purchase.
class InstallmentPurchase {
  final String id;
  final String name;
  final double totalAmount;
  final int installments; // >= 2
  final String purchaseDate; // ISO date string (YYYY-MM-DD) — informational only
  final String firstChargeDate; // ISO date string (YYYY-MM-DD) — anchors every occurrence
  final String createdAt; // ISO date string (YYYY-MM-DD)
  final int chargedInstallments; // 0..installments

  /// Which caixinha the monthly charges come out of, or `null` for the
  /// general account balance — same meaning as on a [Subscription], and
  /// copied onto every [Expense] catch-up generates from this.
  final String? categoryId;

  /// Money paid toward this purchase ON TOP of the scheduled installments —
  /// the user paying extra one month, or settling the whole thing at once.
  ///
  /// Kept as its own running total instead of editing [totalAmount] or
  /// [installments] (both immutable in `firestore.rules`, deliberately: they
  /// are what [chargedInstallments] is counted against, so rewriting them
  /// would desync the progress counter from what was actually billed).
  /// Paying extra shortens the SCHEDULE, not the installment: the remaining
  /// charges stay the same size and the purchase simply ends sooner — see
  /// `recurring_schedule.outstandingAmount`.
  ///
  /// Absent on every purchase created before this field existed, which reads
  /// as 0 — exactly how they already behaved.
  final double amortizedAmount;

  /// Day of the month the REMAINING installments fall due, when the user has
  /// moved it — `null` means "keep [firstChargeDate]'s own day", which is how
  /// every purchase behaved before this field existed.
  ///
  /// It exists because [firstChargeDate] cannot move: it anchors every
  /// occurrence, including the ones already billed, so rewriting it would
  /// retroactively change dates that money already went out on (and is
  /// immutable in `firestore.rules` for that reason). This moves only what
  /// has NOT been charged yet — see `recurring_schedule.installmentDueDate`,
  /// which ignores it for any index below [chargedInstallments].
  ///
  /// Only the DAY moves, never the month: a purchase due in March, April and
  /// May still bills in March, April and May. Short months clamp, same as
  /// everywhere else (see `recurring_schedule.dueDateFor`).
  final int? dueDayOverride;

  const InstallmentPurchase({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.installments,
    required this.purchaseDate,
    required this.firstChargeDate,
    required this.createdAt,
    this.chargedInstallments = 0,
    this.categoryId,
    this.amortizedAmount = 0,
    this.dueDayOverride,
  });

  /// Every field carried over unless named. The doc is rewritten whole on
  /// every charge and every early payment, so a field added here and missed
  /// at one of those sites would be silently erased the next time the user
  /// paid something.
  InstallmentPurchase copyWith({
    int? chargedInstallments,
    double? amortizedAmount,
    int? dueDayOverride,
    bool clearDueDayOverride = false,
  }) {
    return InstallmentPurchase(
      id: id,
      name: name,
      totalAmount: totalAmount,
      installments: installments,
      purchaseDate: purchaseDate,
      firstChargeDate: firstChargeDate,
      createdAt: createdAt,
      chargedInstallments: chargedInstallments ?? this.chargedInstallments,
      categoryId: categoryId,
      amortizedAmount: amortizedAmount ?? this.amortizedAmount,
      dueDayOverride: clearDueDayOverride ? null : (dueDayOverride ?? this.dueDayOverride),
    );
  }

  /// Whether every scheduled occurrence has been billed. NOT the same as
  /// "nothing left to pay" — an early payoff settles the debt with
  /// occurrences still unbilled. Use `recurring_schedule.isSettled` for that.
  bool get isFullyCharged => chargedInstallments >= installments;

  /// Whether the charges come out of a caixinha rather than the account.
  bool get chargesCaixinha => categoryId != null;

  factory InstallmentPurchase.fromMap(String id, Map<String, dynamic> map) {
    return InstallmentPurchase(
      id: id,
      name: map['name'] as String,
      totalAmount: (map['totalAmount'] as num).toDouble(),
      installments: (map['installments'] as num).toInt(),
      purchaseDate: map['purchaseDate'] as String,
      firstChargeDate: map['firstChargeDate'] as String,
      createdAt: map['createdAt'] as String,
      chargedInstallments: (map['chargedInstallments'] as num?)?.toInt() ?? 0,
      categoryId: map['categoryId'] as String?,
      amortizedAmount: (map['amortizedAmount'] as num?)?.toDouble() ?? 0,
      dueDayOverride: (map['dueDayOverride'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'totalAmount': totalAmount,
      'installments': installments,
      'purchaseDate': purchaseDate,
      'firstChargeDate': firstChargeDate,
      'createdAt': createdAt,
      'chargedInstallments': chargedInstallments,
      if (categoryId != null) 'categoryId': categoryId,
      if (amortizedAmount != 0) 'amortizedAmount': amortizedAmount,
      if (dueDayOverride != null) 'dueDayOverride': dueDayOverride,
    };
  }

  factory InstallmentPurchase.fromJson(Map<String, dynamic> json) {
    return InstallmentPurchase.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
