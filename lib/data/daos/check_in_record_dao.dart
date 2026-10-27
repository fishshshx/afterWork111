import '../../models/check_in_record.dart';
import '../app_database.dart';

class CheckInRecordDao {
  final AppDatabase _db;

  CheckInRecordDao(this._db);

  /// 打卡/补打卡。
  ///
  /// 同一 item 同一天只能有一条记录（UNIQUE(item_id, date)）。
  /// 已存在则更新该条（完成状态与备注），不存在则插入。
  Future<CheckInRecord> upsert({
    required int itemId,
    required String date,
    required bool isCompleted,
    String? note,
  }) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final now = DateTime.now().toIso8601String();
      final existing = await txn.query(
        'check_in_records',
        where: 'item_id = ? AND date = ?',
        whereArgs: [itemId, date],
      );
      if (existing.isEmpty) {
        final id = await txn.insert('check_in_records', {
          'item_id': itemId,
          'date': date,
          'is_completed': isCompleted ? 1 : 0,
          'note': note,
          'created_at': now,
          'updated_at': now,
        });
        return CheckInRecord(
          id: id,
          itemId: itemId,
          date: date,
          isCompleted: isCompleted,
          note: note,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );
      }
      await txn.update(
        'check_in_records',
        {
          'is_completed': isCompleted ? 1 : 0,
          'note': note,
          'updated_at': now,
        },
        where: 'id = ?',
        whereArgs: [existing.first['id']],
      );
      return CheckInRecord.fromMap({
        ...existing.first,
        'is_completed': isCompleted ? 1 : 0,
        'note': note,
        'updated_at': now,
      });
    });
  }

  /// 取消某天的打卡（删除该条记录）。
  Future<int> remove(int itemId, String date) async {
    final db = await _db.database;
    return db.delete(
      'check_in_records',
      where: 'item_id = ? AND date = ?',
      whereArgs: [itemId, date],
    );
  }

  /// 获取某打卡项某天的记录。
  Future<CheckInRecord?> getByItemAndDate(int itemId, String date) async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_records',
      where: 'item_id = ? AND date = ?',
      whereArgs: [itemId, date],
    );
    if (maps.isEmpty) return null;
    return CheckInRecord.fromMap(maps.first);
  }

  /// 获取某打卡项的所有打卡记录。
  Future<List<CheckInRecord>> getByItem(int itemId) async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_records',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'date DESC',
    );
    return maps.map((m) => CheckInRecord.fromMap(m)).toList();
  }

  /// 获取某打卡项所有已完成（is_completed = 1）的日期集合。
  Future<Set<String>> getCompletedDates(int itemId) async {
    final db = await _db.database;
    final maps = await db.query(
      'check_in_records',
      columns: ['date'],
      where: 'item_id = ? AND is_completed = 1',
      whereArgs: [itemId],
    );
    return maps.map((m) => m['date'] as String).toSet();
  }
}
