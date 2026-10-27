import '../../models/activity.dart';
import '../app_database.dart';

class ActivityDao {
  final AppDatabase _db;

  ActivityDao(this._db);

  Future<int> insert(Activity activity) async {
    final db = await _db.database;
    return db.insert('activities', activity.toMap());
  }

  Future<int> update(Activity activity) async {
    final db = await _db.database;
    return db.update(
      'activities',
      activity.toMap(),
      where: 'id = ?',
      whereArgs: [activity.id],
    );
  }

  /// 归档活动：默认列表不再显示，但历史记录仍可引用。
  Future<int> archive(int id) async {
    final db = await _db.database;
    return db.update(
      'activities',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 取消归档。
  Future<int> unarchive(int id) async {
    final db = await _db.database;
    return db.update(
      'activities',
      {
        'archived_at': null,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 硬删除活动。若该活动仍被 plan 或 record 引用，则抛出异常。
  Future<int> delete(int id) async {
    final db = await _db.database;

    final planCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM plans WHERE activity_id = ?',
      [id],
    );
    final recordCount = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM records WHERE activity_id = ?',
      [id],
    );

    if (((planCount.first['cnt'] as int?) ?? 0) > 0 ||
        ((recordCount.first['cnt'] as int?) ?? 0) > 0) {
      throw Exception('该活动下存在计划或记录，无法删除');
    }

    return db.delete('activities', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Activity>> getAll({bool includeArchived = false}) async {
    final db = await _db.database;
    final maps = await db.query(
      'activities',
      where: includeArchived ? null : 'archived_at IS NULL',
      orderBy: 'name ASC',
    );
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<List<Activity>> getByCategory(int categoryId,
      {bool includeArchived = false}) async {
    final db = await _db.database;
    final maps = await db.query(
      'activities',
      where: includeArchived
          ? 'category_id = ?'
          : 'category_id = ? AND archived_at IS NULL',
      whereArgs: [categoryId],
      orderBy: 'name ASC',
    );
    return maps.map((map) => Activity.fromMap(map)).toList();
  }

  Future<Activity?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Activity.fromMap(maps.first);
  }
}
