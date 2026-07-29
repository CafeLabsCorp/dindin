/// A fixed recurring monthly expense the user is committed to (e.g.
/// Netflix): the same [amount] charged on [dueDay] every month, straight out
/// of the account balance (never a caixinha — see `docs/ARQUITETURA.pt-br.md`,
/// "Assinaturas").
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

  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.dueDay,
    required this.createdAt,
    this.lastChargedDate,
  });

  factory Subscription.fromMap(String id, Map<String, dynamic> map) {
    return Subscription(
      id: id,
      name: map['name'] as String,
      amount: (map['amount'] as num).toDouble(),
      dueDay: (map['dueDay'] as num).toInt(),
      createdAt: map['createdAt'] as String,
      lastChargedDate: map['lastChargedDate'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'amount': amount,
      'dueDay': dueDay,
      'createdAt': createdAt,
      if (lastChargedDate != null) 'lastChargedDate': lastChargedDate,
    };
  }

  factory Subscription.fromJson(Map<String, dynamic> json) {
    return Subscription.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
