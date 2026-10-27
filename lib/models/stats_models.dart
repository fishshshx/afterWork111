/// 月度统计相关的数据模型。
library;

/// 单项活动的月度统计：次数 + 总时长。
class ActivityStat {
  final int activityId;
  final String activityName;
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final int count;
  final int totalMinutes;

  const ActivityStat({
    required this.activityId,
    required this.activityName,
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.count,
    required this.totalMinutes,
  });

  factory ActivityStat.fromMap(Map<String, dynamic> map) {
    return ActivityStat(
      activityId: map['activity_id'] as int,
      activityName: map['activity_name'] as String,
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      categoryColor: map['category_color'] as String,
      count: map['count'] as int,
      totalMinutes: map['total_minutes'] as int,
    );
  }
}

/// 分类占比统计：某分类在某月的总时长与次数。
class CategoryStat {
  final int categoryId;
  final String categoryName;
  final String categoryColor;
  final int count;
  final int totalMinutes;

  const CategoryStat({
    required this.categoryId,
    required this.categoryName,
    required this.categoryColor,
    required this.count,
    required this.totalMinutes,
  });

  factory CategoryStat.fromMap(Map<String, dynamic> map) {
    return CategoryStat(
      categoryId: map['category_id'] as int,
      categoryName: map['category_name'] as String,
      categoryColor: map['category_color'] as String,
      count: map['count'] as int,
      totalMinutes: map['total_minutes'] as int,
    );
  }
}

/// 单个活动按天聚合的时序点（用于趋势图）。
class ActivityDailyPoint {
  final String date; // YYYY-MM-DD
  final int minutes;
  final int count;

  const ActivityDailyPoint({
    required this.date,
    required this.minutes,
    required this.count,
  });

  factory ActivityDailyPoint.fromMap(Map<String, dynamic> map) {
    return ActivityDailyPoint(
      date: map['record_date'] as String,
      minutes: map['total_minutes'] as int,
      count: map['count'] as int,
    );
  }
}
