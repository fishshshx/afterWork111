import '../../models/check_in_item.dart';
import '../app_database.dart';

class CheckInItemDao {
  final AppDatabase _db;

  CheckInItemDao(this._db);

  Future<int> insert(CheckInItem item) async {
    final db = await _db.database;
    return db.insert('check_in_items', item.toMap());
  }

  Future<int> update(CheckInItem item) async {
    final db = await _db.database;
    return db.update(
      'check_in_items',
      item.toMap(),
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<CheckInItem?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_items',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return CheckInItem.fromMap(maps.first);
  }

  /// 返回所有打卡项，启用中的排前，未启用的靠后，按创建时间排序。
  Future<List<CheckInItem>> getAll() async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_items',
      orderBy: 'is_enabled DESC, created_at ASC',
    );
    return maps.map((m) => CheckInItem.fromMap(m)).toList();
  }

  /// 返回启用中（未归档且 is_enabled）的打卡项。
  Future<List<CheckInItem>> getActive() async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_items',
      where: 'archived_at IS NULL AND is_enabled = 1',
      orderBy: 'created_at ASC',
    );
    return maps.map((m) => CheckInItem.fromMap(m)).toList();
  }

  /// 归档打卡项（软删除），保留历史打卡记录。
  Future<int> archive(int id) async {
    final db = await _db.database;
    return db.update(
      'check_in_items',
      {
        'archived_at': DateTime.now().toIso8601String(),
        'is_enabled': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 取消归档，恢复启用。
  Future<int> unarchive(int id) async {
    final db = await _db.database;
    return db.update(
      'check_in_items',
      {
        'archived_at': null,
        'is_enabled': 1,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// 硬删除打卡项。历史打卡记录 item_id 会被外键 SET NULL。
  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('check_in_items', where: 'id = ?', whereArgs: [id]);
  }
}
