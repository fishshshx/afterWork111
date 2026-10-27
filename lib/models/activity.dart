class Activity {
  final int? id;
  final String name;
  final int categoryId;
  final int? defaultMinutes;
  final DateTime? archivedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  Activity({
    this.id,
    required this.name,
    required this.categoryId,
    this.defaultMinutes,
    this.archivedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => archivedAt != null;

  factory Activity.fromMap(Map<String, dynamic> map) {
    return Activity(
      id: map['id'] as int?,
      name: map['name'] as String,
      categoryId: map['category_id'] as int,
      defaultMinutes: map['default_minutes'] as int?,
      archivedAt:
          map['archived_at'] == null
              ? null
              : DateTime.parse(map['archived_at'] as String),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category_id': categoryId,
      'default_minutes': defaultMinutes,
      'archived_at': archivedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Activity copyWith({
    int? id,
    String? name,
    int? categoryId,
    int? defaultMinutes,
    DateTime? archivedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      categoryId: categoryId ?? this.categoryId,
      defaultMinutes: defaultMinutes ?? this.defaultMinutes,
      archivedAt: archivedAt ?? this.archivedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
