/// A transfer of money from the general account balance into a caixinha
/// (category). Mirrors `AllocationSchema` in the Next.js app's
/// `src/lib/schemas.ts`, minus `incomeId` — allocations draw from the
/// pooled account balance, not from a specific income.
///
/// A caixinha-to-caixinha transfer is modelled as a PAIR of allocations that
/// share the same [transferId]: a negative-amount leg on the source caixinha
/// and a positive-amount leg on the destination. The pair nets to zero against
/// the account balance (total allocated is unchanged), so aggregation stays
/// correct with no changes — see docs/BACKEND.md. A plain allocation has a
/// null [transferId].
class Allocation {
  final String id;
  final String categoryId;
  final double amount;
  final String date; // ISO date string (YYYY-MM-DD)

  /// Non-null when this allocation is one leg of a caixinha-to-caixinha
  /// transfer; the two legs of a transfer share the same value. Nullable and
  /// optional so existing allocation documents and old JSON backups (which
  /// lack it) stay valid.
  final String? transferId;

  const Allocation({
    required this.id,
    required this.categoryId,
    required this.amount,
    required this.date,
    this.transferId,
  });

  /// Whether this allocation is a leg of a caixinha-to-caixinha transfer.
  bool get isTransfer => transferId != null;

  factory Allocation.fromMap(String id, Map<String, dynamic> map) {
    return Allocation(
      id: id,
      categoryId: map['categoryId'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: map['date'] as String,
      transferId: map['transferId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'categoryId': categoryId,
      'amount': amount,
      'date': date,
      if (transferId != null) 'transferId': transferId,
    };
  }

  factory Allocation.fromJson(Map<String, dynamic> json) {
    return Allocation.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
