import 'dart:convert';

import '../../models/record.dart';
import '../../models/record_with_activity.dart';
import '../app_database.dart';
import '../services/photo_file_service.dart';

class RecordDao {
  final AppDatabase _db;
  final Future<PhotoFileService>? _photoServiceFuture;

  RecordDao(this._db, {this._photoServiceFuture});

  Future<int> insert(Record record) async {
    final db = await _db.database;
    return db.insert('records', record.toMap());
  }

  Future<int> update(Record record) async {
    final db = await _db.database;
    return db.update(
      'records',
      record.toMap(),
      where: 'id = ?',
      whereArgs: [record.id],
    );
  }

  /// 删除记录。
  /// 如果该记录关联了计划，且计划当前状态为 completed，
  /// 则在同一事务中将计划状态回退为 pending。
  /// 同时删除该记录关联的照片文件，删除失败不阻塞记录删除。
  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.transaction((txn) async {
      final rows = await txn.query(
        'records',
        where: 'id = ?',
        whereArgs: [id],
      );
      if (rows.isEmpty) return 0;

      final planId = rows.first['plan_id'] as int?;
      final rawPaths = rows.first['photo_paths'] as String?;
      final photoPaths =
          rawPaths == null || rawPaths.isEmpty
              ? <String>[]
              : List<String>.from(jsonDecode(rawPaths) as List);

      final deleted = await txn.delete(
        'records',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (planId != null) {
        await txn.update(
          'plans',
          {
            'status': 'pending',
            'updated_at': DateTime.now().toIso8601String(),
          },
          where: 'id = ? AND status = ?',
          whereArgs: [planId, 'completed'],
        );
      }

      // 事务提交后删除照片文件，失败只记录日志。
      final photoService = await _photoServiceFuture;
      if (photoService != null) {
        for (final path in photoPaths) {
          await photoService.deletePhoto(path);
        }
      }

      return deleted;
    });
  }

  Future<Record?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'records',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Record.fromMap(maps.first);
  }

  Future<Record?> getByPlanId(int planId) async {
    final db = await _db.database;
    final maps = await db.query(
      'records',
      where: 'plan_id = ?',
      whereArgs: [planId],
    );
    if (maps.isEmpty) return null;
    return Record.fromMap(maps.first);
  }

  Future<List<RecordWithActivity>> getAll() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT records.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM records
      JOIN activities ON records.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      ORDER BY records.record_date DESC, records.created_at DESC
    ''');
    return maps.map((map) => RecordWithActivity.fromMap(map)).toList();
  }

  Future<List<RecordWithActivity>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT records.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM records
      JOIN activities ON records.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      WHERE records.record_date = ?
      ORDER BY records.created_at DESC
    ''', [date]);
    return maps.map((map) => RecordWithActivity.fromMap(map)).toList();
  }

  Future<List<RecordWithActivity>> getByDateRange(String startDate,
      String endDate) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT records.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM records
      JOIN activities ON records.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      WHERE records.record_date >= ? AND records.record_date <= ?
      ORDER BY records.record_date DESC, records.created_at DESC
    ''', [startDate, endDate]);
    return maps.map((map) => RecordWithActivity.fromMap(map)).toList();
  }
}
