import 'dart:convert';

class Record {
  final int? id;
  final int? planId;
  final int activityId;
  final String recordDate;
  final int actualMinutes;
  final String? note;
  final List<String> photoPaths;
  final DateTime createdAt;
  final DateTime updatedAt;

  Record({
    this.id,
    this.planId,
    required this.activityId,
    required this.recordDate,
    required this.actualMinutes,
    this.note,
    this.photoPaths = const [],
    required this.createdAt,
    required this.updatedAt,
  });

  factory Record.fromMap(Map<String, dynamic> map) {
    final rawPaths = map['photo_paths'] as String?;
    return Record(
      id: map['id'] as int?,
      planId: map['plan_id'] as int?,
      activityId: map['activity_id'] as int,
      recordDate: map['record_date'] as String,
      actualMinutes: map['actual_minutes'] as int,
      note: map['note'] as String?,
      photoPaths:
          rawPaths == null || rawPaths.isEmpty
              ? []
              : List<String>.from(jsonDecode(rawPaths) as List),
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'plan_id': planId,
      'activity_id': activityId,
      'record_date': recordDate,
      'actual_minutes': actualMinutes,
      'note': note,
      'photo_paths': jsonEncode(photoPaths),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Record copyWith({
    int? id,
    int? planId,
    int? activityId,
    String? recordDate,
    int? actualMinutes,
    String? note,
    List<String>? photoPaths,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Record(
      id: id ?? this.id,
      planId: planId ?? this.planId,
      activityId: activityId ?? this.activityId,
      recordDate: recordDate ?? this.recordDate,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      note: note ?? this.note,
      photoPaths: photoPaths ?? this.photoPaths,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
