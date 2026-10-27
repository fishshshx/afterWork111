// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:after_work/data/app_database.dart';
import 'package:after_work/data/daos/activity_dao.dart';
import 'package:after_work/data/daos/category_dao.dart';
import 'package:after_work/data/daos/plan_dao.dart';
import 'package:after_work/data/daos/record_dao.dart';
import 'package:after_work/data/services/photo_file_service.dart';
import 'package:after_work/data/services/plan_record_service.dart';
import 'package:after_work/models/activity.dart';
import 'package:after_work/models/plan.dart';
import 'package:after_work/models/record.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  AppDatabase.setFactory(databaseFactoryFfi);

  final String testDir = p.join(Directory.systemTemp.path, 'after_work_test');

  group('RecordDao', () {
    AppDatabase? _db;
    late CategoryDao _categoryDao;
    late ActivityDao _activityDao;
    late PlanDao _planDao;
    late RecordDao _recordDao;
    late PlanRecordService _service;
    late Directory _photoBaseDir;
    late Activity _swimActivity;

    setUp(() async {
      await Directory(testDir).create(recursive: true);
      _photoBaseDir = await Directory.systemTemp.createTemp(
        'after_work_record_dao_photo_',
      );
      _db = AppDatabase.test(
        p.join(testDir, 'record_dao_test.db'),
        databaseFactoryFfi,
      );
      final photoService = PhotoFileService(baseDirectory: _photoBaseDir);
      _categoryDao = CategoryDao(_db!);
      _activityDao = ActivityDao(_db!);
      _planDao = PlanDao(_db!);
      _recordDao = RecordDao(_db!, photoServiceFuture: Future.value(photoService));
      _service = PlanRecordService(_db!);

      final categories = await _categoryDao.getAll();
      final sportCategory = categories.firstWhere((c) => c.name == '运动');
      final swimId = await _activityDao.insert(
        Activity(
          name: '游泳',
          categoryId: sportCategory.id!,
          defaultMinutes: 60,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      _swimActivity = (await _activityDao.getById(swimId))!;
    });

    tearDown(() async {
      await _db?.close();
      _db = null;
      final dbFile = File(p.join(testDir, 'record_dao_test.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      if (await _photoBaseDir.exists()) {
        await _photoBaseDir.delete(recursive: true);
      }
    });

    test('directly added record has plan_id null and does not rollback plan on delete',
        () async {
      final now = DateTime.now();
      final record = Record(
        planId: null,
        activityId: _swimActivity.id!,
        recordDate: '2026-10-19',
        actualMinutes: 40,
        note: '直接补录',
        createdAt: now,
        updatedAt: now,
      );
      final recordId = await _recordDao.insert(record);

      final saved = await _recordDao.getById(recordId);
      expect(saved?.planId, isNull);

      await _recordDao.delete(recordId);

      final deleted = await _recordDao.getById(recordId);
      expect(deleted, isNull);
    });

    test('deleting record linked to completed plan rolls plan back to pending',
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

    test('deleting record removes its photo files', () async {
      final photoService = PhotoFileService(baseDirectory: _photoBaseDir);
      final photosDir = await photoService.getPhotosDirectory();

      // 创建测试照片文件
      final image = img.Image(width: 100, height: 100);
      final photoBytes = img.encodeJpg(image);
      final photoFile = File(p.join(_photoBaseDir.path, 'test.jpg'));
      await photoFile.writeAsBytes(photoBytes);

      final relativePath = await photoService.copyAndCompressPhoto(photoFile);
      final savedFile = File(p.join(photosDir.path, relativePath));
      expect(await savedFile.exists(), isTrue);

      final now = DateTime.now();
      final recordId = await _recordDao.insert(
        Record(
          planId: null,
          activityId: _swimActivity.id!,
          recordDate: '2026-10-19',
          actualMinutes: 30,
          photoPaths: [relativePath],
          createdAt: now,
          updatedAt: now,
        ),
      );

      await _recordDao.delete(recordId);

      expect(await savedFile.exists(), isFalse);
      expect(await _recordDao.getById(recordId), isNull);
    });
  });
}
