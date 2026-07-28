/// A card purchase split into fixed monthly installments (e.g. "Notebook Dell,
/// R$ 1.200 em 12x"): the total amount is charged in equal monthly slices —
/// see `FirestoreService._installmentAmounts` for the exact split, which puts
/// any rounding remainder on the LAST installment (matches a real card bill) —
/// straight out of the account balance, same as a [Subscription].
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

  const InstallmentPurchase({
    required this.id,
    required this.name,
    required this.totalAmount,
    required this.installments,
    required this.purchaseDate,
    required this.firstChargeDate,
    required this.createdAt,
    this.chargedInstallments = 0,
  });

  bool get isFullyCharged => chargedInstallments >= installments;

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
    };
  }

  factory InstallmentPurchase.fromJson(Map<String, dynamic> json) {
    return InstallmentPurchase.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
