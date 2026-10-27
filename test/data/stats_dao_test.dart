import 'dart:io';

import 'package:after_work/data/app_database.dart';
import 'package:after_work/data/daos/activity_dao.dart';
import 'package:after_work/data/daos/category_dao.dart';
import 'package:after_work/data/daos/record_dao.dart';
import 'package:after_work/data/daos/stats_dao.dart';
import 'package:after_work/models/activity.dart';
import 'package:after_work/models/record.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late CategoryDao categoryDao;
  late ActivityDao activityDao;
  late RecordDao recordDao;
  late StatsDao statsDao;
  final testDir = p.join(Directory.systemTemp.path, 'after_work_stats_test');

  int sportCategoryId = 0;
  int studyCategoryId = 0;
  int swimActivityId = 0;
  int guitarActivityId = 0;

  setUp(() async {
    await Directory(testDir).create(recursive: true);
    db = AppDatabase.test(p.join(testDir, 'test.db'), databaseFactoryFfi);
    categoryDao = CategoryDao(db);
    activityDao = ActivityDao(db);
    recordDao = RecordDao(db);
    statsDao = StatsDao(db);

    // 找到预置分类
    final categories = await categoryDao.getAll();
    sportCategoryId = categories
        .firstWhere((c) => c.name == '运动')
        .id!;
    studyCategoryId = categories
        .firstWhere((c) => c.name == '学习')
        .id!;

    // 创建活动
    final now = DateTime.now();
    final swim = Activity(
      name: '游泳',
      categoryId: sportCategoryId,
      createdAt: now,
      updatedAt: now,
    );
    swimActivityId = await activityDao.insert(swim);
    final guitar = Activity(
      name: '吉他',
      categoryId: studyCategoryId,
      createdAt: now,
      updatedAt: now,
    );
    guitarActivityId = await activityDao.insert(guitar);
  });

  tearDown(() async {
    await db.close();
    final f = File(p.join(testDir, 'test.db'));
    if (await f.exists()) await f.delete();
  });

  Record makeRecord({
    required int activityId,
    required String date,
    required int minutes,
  }) {
    final now = DateTime.now();
    return Record(
      activityId: activityId,
      recordDate: date,
      actualMinutes: minutes,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('活动统计按活动聚合次数与总时长，按总时长降序', () async {
    // 游泳 3 次共 160 分钟（10月内 2 次 + 11月 1 次）
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-05', minutes: 40),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-12', minutes: 45),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-11-03', minutes: 75),
    );
    // 吉他 10月 2 次共 110 分钟
    await recordDao.insert(
      makeRecord(activityId: guitarActivityId, date: '2026-10-08', minutes: 55),
    );
    await recordDao.insert(
      makeRecord(activityId: guitarActivityId, date: '2026-10-15', minutes: 55),
    );

    final stats = await statsDao.getActivityStats('2026-10-01', '2026-10-31');

    // 10月：吉他 110 分钟 > 游泳 85 分钟
    expect(stats.length, 2);
    expect(stats.first.activityName, '吉他');
    expect(stats.first.totalMinutes, 110);
    expect(stats.first.count, 2);

    final swim = stats.firstWhere((s) => s.activityName == '游泳');
    expect(swim.totalMinutes, 85);
    expect(swim.count, 2);
    expect(swim.categoryName, '运动');
  });

  test('分类统计聚合总时长与次数', () async {
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-05', minutes: 40),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-12', minutes: 45),
    );
    await recordDao.insert(
      makeRecord(activityId: guitarActivityId, date: '2026-10-08', minutes: 55),
    );

    final stats = await statsDao.getCategoryStats('2026-10-01', '2026-10-31');

    expect(stats.length, 2);
    final sport = stats.firstWhere((s) => s.categoryName == '运动');
    final study = stats.firstWhere((s) => s.categoryName == '学习');
    expect(sport.totalMinutes, 85);
    expect(sport.count, 2);
    expect(study.totalMinutes, 55);
    expect(study.count, 1);
  });

  test('单项活动按天趋势按日期升序', () async {
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-05', minutes: 40),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-12', minutes: 45),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-12', minutes: 30),
    );

    final points = await statsDao.getActivityDaily(
      swimActivityId,
      '2026-10-01',
      '2026-10-31',
    );

    expect(points.length, 2);
    expect(points.first.date, '2026-10-05');
    expect(points.first.minutes, 40);
    expect(points.first.count, 1);
    // 10-12 当天两条合并
    expect(points[1].date, '2026-10-12');
    expect(points[1].minutes, 75);
    expect(points[1].count, 2);
  });

  test('月度概览汇总总时长与总次数', () async {
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-10-05', minutes: 40),
    );
    await recordDao.insert(
      makeRecord(activityId: guitarActivityId, date: '2026-10-08', minutes: 55),
    );
    await recordDao.insert(
      makeRecord(activityId: swimActivityId, date: '2026-11-03', minutes: 75),
    );

    final summary = await statsDao.getMonthSummary('2026-10-01', '2026-10-31');
    expect(summary.totalCount, 2);
    expect(summary.totalMinutes, 95);
  });
}
