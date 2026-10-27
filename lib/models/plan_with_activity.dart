import 'activity.dart';
import 'category.dart';
import 'plan.dart';

class PlanWithActivity {
  final Plan plan;
  final Activity activity;
  final Category category;

  PlanWithActivity({
    required this.plan,
    required this.activity,
    required this.category,
  });

  factory PlanWithActivity.fromMap(Map<String, dynamic> map) {
    return PlanWithActivity(
      plan: Plan.fromMap(map),
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
