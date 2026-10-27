import '../../models/stats_models.dart';
import '../app_database.dart';

/// 月度统计查询。
class StatsDao {
  final AppDatabase _db;

  StatsDao(this._db);

  /// 某月各活动的次数与总时长排行（按总时长降序）。
  Future<List<ActivityStat>> getActivityStats(String monthStart, String monthEnd) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT
        a.id AS activity_id,
        a.name AS activity_name,
        c.id AS category_id,
        c.name AS category_name,
        c.color AS category_color,
        COUNT(r.id) AS count,
        COALESCE(SUM(r.actual_minutes), 0) AS total_minutes
      FROM records r
      JOIN activities a ON r.activity_id = a.id
      JOIN categories c ON a.category_id = c.id
      WHERE r.record_date >= ? AND r.record_date <= ?
      GROUP BY a.id, a.name, c.id, c.name, c.color
      ORDER BY total_minutes DESC, count DESC
    ''', [monthStart, monthEnd]);
    return maps.map((m) => ActivityStat.fromMap(m)).toList();
  }

  /// 某月各分类的占比（按总时长降序）。
  Future<List<CategoryStat>> getCategoryStats(String monthStart, String monthEnd) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT
        c.id AS category_id,
        c.name AS category_name,
        c.color AS category_color,
        COUNT(r.id) AS count,
        COALESCE(SUM(r.actual_minutes), 0) AS total_minutes
      FROM records r
      JOIN activities a ON r.activity_id = a.id
      JOIN categories c ON a.category_id = c.id
      WHERE r.record_date >= ? AND r.record_date <= ?
      GROUP BY c.id, c.name, c.color
      ORDER BY total_minutes DESC, count DESC
    ''', [monthStart, monthEnd]);
    return maps.map((m) => CategoryStat.fromMap(m)).toList();
  }

  /// 某月某活动按天聚合的时序（用于趋势图）。
  Future<List<ActivityDailyPoint>> getActivityDaily(
    int activityId,
    String monthStart,
    String monthEnd,
  ) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT
        r.record_date,
        COALESCE(SUM(r.actual_minutes), 0) AS total_minutes,
        COUNT(r.id) AS count
      FROM records r
      WHERE r.activity_id = ? AND r.record_date >= ? AND r.record_date <= ?
      GROUP BY r.record_date
      ORDER BY r.record_date ASC
    ''', [activityId, monthStart, monthEnd]);
    return maps.map((m) => ActivityDailyPoint.fromMap(m)).toList();
  }

  /// 某月的总记录时长与总次数（用于顶部概览）。
  Future<({int totalMinutes, int totalCount})> getMonthSummary(
    String monthStart,
    String monthEnd,
  ) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT
        COALESCE(SUM(actual_minutes), 0) AS total_minutes,
        COUNT(*) AS total_count
      FROM records
      WHERE record_date >= ? AND record_date <= ?
    ''', [monthStart, monthEnd]);
    final row = maps.first;
    return (
      totalMinutes: row['total_minutes'] as int,
      totalCount: row['total_count'] as int,
    );
  }
}
