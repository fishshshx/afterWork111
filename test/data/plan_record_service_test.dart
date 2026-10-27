import 'dart:io';

// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:after_work/data/app_database.dart';
import 'package:after_work/data/daos/activity_dao.dart';
import 'package:after_work/data/daos/category_dao.dart';
import 'package:after_work/data/daos/plan_dao.dart';
import 'package:after_work/data/daos/record_dao.dart';
import 'package:after_work/data/services/plan_record_service.dart';
import 'package:after_work/models/activity.dart';
import 'package:after_work/models/category.dart';
import 'package:after_work/models/plan.dart';
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  AppDatabase.setFactory(databaseFactoryFfi);

  final String testDir = join(Directory.systemTemp.path, 'after_work_test');

  group('PlanRecordService', () {
    AppDatabase? _db;
    late CategoryDao _categoryDao;
    late ActivityDao _activityDao;
    late PlanDao _planDao;
    late RecordDao _recordDao;
    late PlanRecordService _service;
    late Category _sportCategory;
    late Activity _swimActivity;

    setUp(() async {
      await Directory(testDir).create(recursive: true);
      _db = AppDatabase.test(join(testDir, 'plan_record_service_test.db'), databaseFactoryFfi);
      _categoryDao = CategoryDao(_db!);
      _activityDao = ActivityDao(_db!);
      _planDao = PlanDao(_db!);
      _recordDao = RecordDao(_db!);
      _service = PlanRecordService(_db!);

      final categories = await _categoryDao.getAll();
      _sportCategory = categories.firstWhere((c) => c.name == '运动');
      final swimId = await _activityDao.insert(Activity(
        name: '游泳',
        categoryId: _sportCategory.id!,
        defaultMinutes: 60,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      _swimActivity = (await _activityDao.getById(swimId))!;
    });

    tearDown(() async {
      await _db?.close();
      _db = null;
      final dbFile = File(join(testDir, 'plan_record_service_test.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    });

    test('completing a pending plan creates a record in a transaction',
        () async {
      final now = DateTime.now();
      final plan = Plan(
        activityId: _swimActivity.id!,
        planDate: '2026-10-19',
        planTime: '19:30',
        estimatedMinutes: 60,
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      final planId = await _planDao.insert(plan);

      await _service.completePlan(
        planId: planId,
        activityId: _swimActivity.id!,
        recordDate: '2026-10-19',
        actualMinutes: 55,
        note: '感觉不错',
      );

      final updatedPlan = await _planDao.getById(planId);
      expect(updatedPlan?.status, 'completed');

      final record = await _recordDao.getByPlanId(planId);
      expect(record, isNotNull);
      expect(record!.activityId, _swimActivity.id);
      expect(record.actualMinutes, 55);
      expect(record.recordDate, '2026-10-19');
    });

    test('completing a plan twice throws PlanAlreadyCompletedException',
        () async {
      final now = DateTime.now();
      final plan = Plan(
        activityId: _swimActivity.id!,
        planDate: '2026-10-19',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      final planId = await _planDao.insert(plan);

      await _service.completePlan(
        planId: planId,
        activityId: _swimActivity.id!,
        recordDate: '2026-10-19',
        actualMinutes: 30,
      );

      expect(
        () async => await _service.completePlan(
          planId: planId,
          activityId: _swimActivity.id!,
          recordDate: '2026-10-19',
          actualMinutes: 40,
        ),
        throwsA(isA<PlanAlreadyCompletedException>()),
      );
    });

    test('completing a non-pending plan throws InvalidPlanStatusException',
        () async {
      final now = DateTime.now();
      final plan = Plan(
        activityId: _swimActivity.id!,
        planDate: '2026-10-19',
        status: 'skipped',
        createdAt: now,
        updatedAt: now,
      );
      final planId = await _planDao.insert(plan);

      expect(
        () async => await _service.completePlan(
          planId: planId,
          activityId: _swimActivity.id!,
          recordDate: '2026-10-19',
          actualMinutes: 30,
        ),
        throwsA(isA<InvalidPlanStatusException>()),
      );
    });

    test('deleting a record rolls linked completed plan back to pending',
        () async {
      final now = DateTime.now();
      final plan = Plan(
        activityId: _swimActivity.id!,
        planDate: '2026-10-19',
        status: 'pending',
        createdAt: now,
        updatedAt: now,
      );
      final planId = await _planDao.insert(plan);

      await _service.completePlan(
        planId: planId,
        activityId: _swimActivity.id!,
        recordDate: '2026-10-19',
        actualMinutes: 45,
      );

      final completedPlan = await _planDao.getById(planId);
      expect(completedPlan?.status, 'completed');

      final record = await _recordDao.getByPlanId(planId);
      await _recordDao.delete(record!.id!);

      final rolledBackPlan = await _planDao.getById(planId);
      expect(rolledBackPlan?.status, 'pending');
    });
  });
}
