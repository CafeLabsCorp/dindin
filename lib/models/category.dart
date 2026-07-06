/// Mirrors `CategorySchema` in the Next.js app's `src/lib/schemas.ts`.
class Category {
  final String id;
  final String name;
  final bool recurring;
  final String createdAt; // ISO date string (YYYY-MM-DD)

  const Category({
    required this.id,
    required this.name,
    required this.recurring,
    required this.createdAt,
  });

  factory Category.fromMap(String id, Map<String, dynamic> map) {
    return Category(
      id: id,
      name: map['name'] as String,
      recurring: map['recurring'] as bool,
      createdAt: map['createdAt'] as String,
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'recurring': recurring, 'createdAt': createdAt};
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category.fromMap(json['id'] as String, json);
  }

  Map<String, dynamic> toJson() => {'id': id, ...toMap()};
}
