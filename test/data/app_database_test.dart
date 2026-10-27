import 'dart:io';

// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:after_work/data/app_database.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  // 初始化 FFI 数据库工厂，用于桌面/测试环境。
  sqfliteFfiInit();
  AppDatabase.setFactory(databaseFactoryFfi);

  final String testDir = join(Directory.systemTemp.path, 'after_work_test');

  group('AppDatabase schema & seed', () {
    AppDatabase? _db;

    setUp(() async {
      await Directory(testDir).create(recursive: true);
      _db = AppDatabase.test(join(testDir, 'app_database_test.db'), databaseFactoryFfi);
    });

    tearDown(() async {
      await _db?.close();
      _db = null;
      final dbFile = File(join(testDir, 'app_database_test.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    });

    Future<dynamic> _database() async => _db!.database;

    test('creates all expected tables', () async {
      final database = await _database();
      final tables = await database.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name",
      );
      final names = tables.map((t) => t['name'] as String).toList();

      expect(names, containsAll(<String>[
        'activities',
        'categories',
        'check_in_items',
        'check_in_records',
        'plans',
        'records',
      ]));
    });

    test('seeds 6 preset categories on first create', () async {
      final database = await _database();
      final rows = await database.query('categories');

      expect(rows.length, 6);
      expect(
        rows.map((r) => r['name'] as String).toList(),
        containsAll(<String>['运动', '学习', '娱乐', '创作', '社交', '其他']),
      );
    });

    test('cannot delete category referenced by activity', () async {
      final database = await _database();
      final now = DateTime.now().toIso8601String();

      final categories = await database.query('categories');
      final sportId = categories.firstWhere(
        (c) => c['name'] == '运动',
      )['id'] as int;

      await database.insert('activities', {
        'name': '游泳',
        'category_id': sportId,
        'created_at': now,
        'updated_at': now,
      });

      expect(
        () async => await database.delete(
          'categories',
          where: 'id = ?',
          whereArgs: [sportId],
        ),
        throwsException,
      );
    });

    test('records.plan_id UNIQUE constraint prevents duplicate record per plan',
        () async {
      final database = await _database();
      final now = DateTime.now().toIso8601String();

      final categories = await database.query('categories');
      final sportId = categories.firstWhere(
        (c) => c['name'] == '运动',
      )['id'] as int;

      final activityId = await database.insert('activities', {
        'name': '游泳',
        'category_id': sportId,
        'created_at': now,
        'updated_at': now,
      });

      final planId = await database.insert('plans', {
        'activity_id': activityId,
        'plan_date': '2026-10-19',
        'status': 'pending',
        'created_at': now,
        'updated_at': now,
      });

      await database.insert('records', {
        'plan_id': planId,
        'activity_id': activityId,
        'record_date': '2026-10-19',
        'actual_minutes': 30,
        'created_at': now,
        'updated_at': now,
      });

      expect(
        () async => await database.insert('records', {
          'plan_id': planId,
          'activity_id': activityId,
          'record_date': '2026-10-19',
          'actual_minutes': 45,
          'created_at': now,
          'updated_at': now,
        }),
        throwsException,
      );
    });
  });
}
