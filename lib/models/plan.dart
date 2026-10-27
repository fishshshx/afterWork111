class Plan {
  final int? id;
  final int activityId;
  final String planDate;
  final String? planTime;
  final int? estimatedMinutes;
  final String? note;
  final String status; // pending / completed / skipped / cancelled
  final DateTime createdAt;
  final DateTime updatedAt;

  Plan({
    this.id,
    required this.activityId,
    required this.planDate,
    this.planTime,
    this.estimatedMinutes,
    this.note,
    this.status = 'pending',
    required this.createdAt,
    required this.updatedAt,
  });

  factory Plan.fromMap(Map<String, dynamic> map) {
    return Plan(
      id: map['id'] as int?,
      activityId: map['activity_id'] as int,
      planDate: map['plan_date'] as String,
      planTime: map['plan_time'] as String?,
      estimatedMinutes: map['estimated_minutes'] as int?,
      note: map['note'] as String?,
      status: map['status'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'activity_id': activityId,
      'plan_date': planDate,
      'plan_time': planTime,
      'estimated_minutes': estimatedMinutes,
      'note': note,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Plan copyWith({
    int? id,
    int? activityId,
    String? planDate,
    String? planTime,
    int? estimatedMinutes,
    String? note,
    String? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Plan(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      planDate: planDate ?? this.planDate,
      planTime: planTime ?? this.planTime,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      note: note ?? this.note,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
