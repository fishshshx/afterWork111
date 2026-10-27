class CheckInRecord {
  final int? id;
  final int? itemId;
  final String date;
  final bool isCompleted;
  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  CheckInRecord({
    this.id,
    this.itemId,
    required this.date,
    this.isCompleted = true,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CheckInRecord.fromMap(Map<String, dynamic> map) {
    return CheckInRecord(
      id: map['id'] as int?,
      itemId: map['item_id'] as int?,
      date: map['date'] as String,
      isCompleted: (map['is_completed'] as int) == 1,
      note: map['note'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'date': date,
      'is_completed': isCompleted ? 1 : 0,
      'note': note,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  CheckInRecord copyWith({
    int? id,
    int? itemId,
    String? date,
    bool? isCompleted,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return CheckInRecord(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      date: date ?? this.date,
      isCompleted: isCompleted ?? this.isCompleted,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
