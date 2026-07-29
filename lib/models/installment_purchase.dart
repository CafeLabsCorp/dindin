/// A card purchase split into fixed monthly installments (e.g. "Notebook Dell,
/// R$ 1.200 em 12x"): the total amount is charged in equal monthly slices —
/// see `recurring_schedule.installmentAmounts` for the exact split, which puts
/// any rounding remainder on the LAST installment (matches a real card bill) —
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
  });

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
    };
  }

  factory InstallmentPurchase.fromJson(Map<String, dynamic> json) {
    return InstallmentPurchase.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
