/// A fixed recurring monthly expense the user is committed to (e.g.
/// Netflix): the same [amount] charged on [dueDay] every month, out of the
/// account balance by default or out of a caixinha when [categoryId] says so
/// (see `docs/ARQUITETURA.pt-br.md`, "Assinaturas").
///
/// [lastChargedDate] tracks the most recent due date this subscription has
/// already generated an [Expense] for (via
/// `FirestoreService.catchUpSubscriptions`), so catch-up never double-charges
/// a month it already processed. `null` means no charge has been generated
/// yet.
class Subscription {
  final String id;
  final String name;
  final double amount;

  /// 1-31. A month shorter than this is clamped to its last day (see
  /// `recurring_schedule.dueDateFor`) — e.g. dueDay 31 charges on Feb 28/29.
  final int dueDay;
  final String createdAt; // ISO date string (YYYY-MM-DD)
  final String? lastChargedDate; // ISO date string (YYYY-MM-DD)

  /// Which caixinha this charge comes out of, or `null` for the general
  /// account balance — the same meaning `categoryId` has on an [Expense], and
  /// the value copied onto every [Expense] catch-up generates from this.
  ///
  /// Only a `spend` caixinha is offered in the UI: a `save` caixinha is a
  /// savings goal, and draining it monthly to pay Netflix contradicts what it
  /// is for. Absent on every subscription created before this field existed,
  /// which reads as "the account" — exactly how they already behaved.
  final String? categoryId;

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.createdAt,
    this.lastChargedDate,
    this.categoryId,
  });

  /// Whether this charge comes out of a caixinha rather than the account.
  bool get chargesCaixinha => categoryId != null;

  factory Subscription.fromMap(String id, Map<String, dynamic> map) {
    return Subscription(
      id: id,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDay: (map['dueDay'] as num).toInt(),
      createdAt: map['createdAt'] as String,
      lastChargedDate: map['lastChargedDate'] as String?,
      categoryId: map['categoryId'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'dueDay': dueDay,
      'createdAt': createdAt,
      if (lastChargedDate != null) 'lastChargedDate': lastChargedDate,
      if (categoryId != null) 'categoryId': categoryId,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
