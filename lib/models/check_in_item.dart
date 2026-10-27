class CheckInItem {
  final int? id;
  final String name;
  final String frequency; // daily
  final String startDate;
  final String? archivedAt;
  final bool isEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckInItem({
    this.id,
    required this.name,
    this.frequency = 'daily',
    required this.startDate,
    this.archivedAt,
    this.isEnabled = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CheckInItem.fromMap(Map<String, dynamic> map) {
    return CheckInItem(
      id: map['id'] as int?,
      name: map['name'] as String,
      frequency: map['frequency'] as String,
      startDate: map['start_date'] as String,
      archivedAt: map['archived_at'] as String?,
      isEnabled: (map['is_enabled'] as int) == 1,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'frequency': frequency,
      'start_date': startDate,
      'archived_at': archivedAt,
      'is_enabled': isEnabled ? 1 : 0,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CheckInItem copyWith({
    int? id,
    String? name,
    String? frequency,
    String? startDate,
    String? archivedAt,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckInItem(
      id: id ?? this.id,
      name: name ?? this.name,
      frequency: frequency ?? this.frequency,
      startDate: startDate ?? this.startDate,
      archivedAt: archivedAt ?? this.archivedAt,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
