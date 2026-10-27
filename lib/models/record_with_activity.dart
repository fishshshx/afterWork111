import 'activity.dart';
import 'category.dart';
import 'record.dart';

class RecordWithActivity {
  final Record record;
  final Activity activity;
  final Category category;

  RecordWithActivity({
    required this.record,
    required this.activity,
    required this.category,
  });

  factory RecordWithActivity.fromMap(Map<String, dynamic> map) {
    return RecordWithActivity(
      record: Record.fromMap(map),
      activity: Activity(
        id: map['activity_id'] as int,
        name: map['activity_name'] as String,
        categoryId: map['category_id'] as int,
        defaultMinutes: map['activity_default_minutes'] as int?,
        createdAt: DateTime.parse(map['activity_created_at'] as String),
        updatedAt: DateTime.parse(map['activity_updated_at'] as String),
      ),
      category: Category(
        id: map['category_id'] as int,
        name: map['category_name'] as String,
        color: map['category_color'] as String,
        sortOrder: map['category_sort_order'] as int? ?? 0,
        createdAt: DateTime.parse(map['category_created_at'] as String),
        updatedAt: DateTime.parse(map['category_updated_at'] as String),
      ),
    );
  }
}
