import 'dart:convert';
import 'dart:io';

// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'package:after_work/data/app_database.dart';
import 'package:after_work/data/daos/activity_dao.dart';
import 'package:after_work/data/daos/category_dao.dart';
import 'package:after_work/data/daos/check_in_item_dao.dart';
import 'package:after_work/data/daos/check_in_record_dao.dart';
import 'package:after_work/data/daos/plan_dao.dart';
import 'package:after_work/data/daos/record_dao.dart';
import 'package:after_work/data/services/data_export_service.dart';
import 'package:after_work/data/services/photo_file_service.dart';
import 'package:after_work/models/activity.dart';
import 'package:after_work/models/check_in_item.dart';
import 'package:after_work/models/plan.dart';
import 'package:after_work/models/record.dart';
import 'package:archive/archive.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();
  AppDatabase.setFactory(databaseFactoryFfi);

  final String testDir = join(Directory.systemTemp.path, 'after_work_export_test');

  group('DataExportService', () {
    AppDatabase? _db;
    late CategoryDao _categoryDao;
    late ActivityDao _activityDao;
    late PlanDao _planDao;
    late RecordDao _recordDao;
    late CheckInItemDao _checkInItemDao;
    late CheckInRecordDao _checkInRecordDao;
    late PhotoFileService _photoService;
    late DataExportService _service;

    late int _sportCategoryId;
    late int _swimActivityId;

    setUp(() async {
      await Directory(testDir).create(recursive: true);
      _db = AppDatabase.test(
        join(testDir, 'export_service_test.db'),
        databaseFactoryFfi,
      );
      _categoryDao = CategoryDao(_db!);
      _activityDao = ActivityDao(_db!);
      _planDao = PlanDao(_db!);
      _recordDao = RecordDao(_db!);
      _checkInItemDao = CheckInItemDao(_db!);
      _checkInRecordDao = CheckInRecordDao(_db!);

      final photosDir = Directory(join(testDir, 'export_photos'));
      await photosDir.create(recursive: true);
      _photoService = PhotoFileService(baseDirectory: photosDir);
      _service = DataExportService(_db!, _photoService);

      final categories = await _categoryDao.getAll();
      _sportCategoryId = categories.firstWhere((c) => c.name == '运动').id!;
      _swimActivityId = await _activityDao.insert(Activity(
        name: '游泳',
        categoryId: _sportCategoryId,
        defaultMinutes: 60,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });

    tearDown(() async {
      await _db?.close();
      _db = null;
      final dbFile = File(join(testDir, 'export_service_test.db'));
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
      final photosDir = Directory(join(testDir, 'export_photos'));
      try {
        if (await photosDir.exists()) {
          await photosDir.delete(recursive: true);
        }
      } on FileSystemException {
        // 忽略 Windows 偶发句柄未释放。
      }
    });

    Future<void> seedData() async {
      // 计划 + 记录
      final planId = await _planDao.insert(Plan(
        activityId: _swimActivityId,
        planDate: '2026-10-27',
        estimatedMinutes: 60,
        status: 'completed',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await _recordDao.insert(Record(
        planId: planId,
        activityId: _swimActivityId,
        recordDate: '2026-10-27',
        actualMinutes: 45,
        note: '测试记录',
        photoPaths: const [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));

      // 打卡项 + 打卡记录
      final itemId = await _checkInItemDao.insert(CheckInItem(
        name: '早起',
        frequency: 'daily',
        startDate: '2026-10-01',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
      await _checkInRecordDao.upsert(
        itemId: itemId,
        date: '2026-10-27',
        isCompleted: true,
      );
    }

    test('exportToJson 返回包含六张表的 JSON', () async {
      await seedData();

      final jsonStr = await _service.exportToJson();
      final manifest = jsonDecode(jsonStr) as Map<String, dynamic>;

      expect(manifest['format_version'], kExportFormatVersion);
      expect(manifest['categories'], isNotEmpty);
      expect(manifest['activities'], isNotEmpty);
      expect(manifest['plans'], isNotEmpty);
      expect(manifest['records'], isNotEmpty);
      expect(manifest['check_in_items'], isNotEmpty);
      expect(manifest['check_in_records'], isNotEmpty);
    });

    test('exportToZip 生成 zip 文件且可解压', () async {
      await seedData();
      // 添加一张照片。
      final image = img.Image(width: 100, height: 100);
      final sourceBytes = img.encodeJpg(image, quality: 90);
      final sourceFile = File(join(testDir, 'tmp_source.jpg'));
      await sourceFile.writeAsBytes(sourceBytes);
      await _photoService.copyAndCompressPhoto(sourceFile);

      final zipPath = join(testDir, 'backup.zip');
      final size = await _service.exportToZip(zipPath);

      expect(size, greaterThan(0));
      final zipFile = File(zipPath);
      expect(await zipFile.exists(), isTrue);
      expect(await zipFile.length(), greaterThan(0));

      // 清理
      if (await zipFile.exists()) await zipFile.delete();
      if (await sourceFile.exists()) await sourceFile.delete();
    });

    test('importFromJson 覆盖导入全部数据', () async {
      await seedData();

      final jsonStr = await _service.exportToJson();
      // 修改数据后再导入，验证覆盖。
      final result = await _service.importFromJson(jsonStr);

      expect(result.categories, greaterThan(0));
      expect(result.activities, 1);
      expect(result.plans, 1);
      expect(result.records, 1);
      expect(result.checkInItems, 1);
      expect(result.checkInRecords, 1);

      // 验证数据仍在。
      final activities = await _activityDao.getAll(includeArchived: true);
      expect(activities.any((a) => a.name == '游泳'), isTrue);
      final records = await _recordDao.getAll();
      expect(records.length, 1);
    });

    test('importFromZip 恢复 JSON 与照片', () async {
      await seedData();
      // 添加照片并写入记录。
      final image = img.Image(width: 100, height: 100);
      final sourceBytes = img.encodeJpg(image, quality: 90);
      final sourceFile = File(join(testDir, 'tmp_source2.jpg'));
      await sourceFile.writeAsBytes(sourceBytes);
      final photoPath = await _photoService.copyAndCompressPhoto(sourceFile);

      final records = await _recordDao.getAll();
      final record = records.first.record;
      await _recordDao.update(record.copyWith(photoPaths: [photoPath]));

      // 导出 zip。
      final zipPath = join(testDir, 'backup2.zip');
      await _service.exportToZip(zipPath);

      // 清空照片目录，模拟新设备。
      final photosDir = await _photoService.getPhotosDirectory();
      await photosDir.delete(recursive: true);

      // 导入。
      final result = await _service.importFromZip(zipPath);
      expect(result.records, 1);

      // 验证照片已恢复。
      final restoredPhotosDir = await _photoService.getPhotosDirectory();
      final restoredFile = File(join(restoredPhotosDir.path, photoPath));
      expect(await restoredFile.exists(), isTrue);

      // 清理。
      final zipFile = File(zipPath);
      if (await zipFile.exists()) await zipFile.delete();
      if (await sourceFile.exists()) await sourceFile.delete();
    });

    test('importFromJson 拒绝非法 JSON', () async {
      await expectLater(
        _service.importFromJson('not json'),
        throwsA(isA<FormatException>()),
      );
    });

    test('importFromJson 拒绝缺少字段的备份', () async {
      await expectLater(
        _service.importFromJson(
          jsonEncode({'format_version': kExportFormatVersion}),
        ),
        throwsA(isA<InvalidBackupException>()),
      );
    });

    test('importFromJson 拒绝不支持的版本', () async {
      await expectLater(
        _service.importFromJson(
          jsonEncode({
            'format_version': 999,
            'categories': [],
            'activities': [],
            'plans': [],
            'records': [],
            'check_in_items': [],
            'check_in_records': [],
          }),
        ),
        throwsA(isA<InvalidBackupException>()),
      );
    });

    test('importFromZip 拒绝缺少 manifest 的 zip', () async {
      // 构造一个不含 data.json 的 zip。
      final zipPath = join(testDir, 'invalid.zip');
      final emptyZip = ZipEncoder().encode(Archive());
      File(zipPath).writeAsBytesSync(emptyZip);
      await expectLater(
        _service.importFromZip(zipPath),
        throwsA(isA<InvalidBackupException>()),
      );
      final f = File(zipPath);
      if (await f.exists()) await f.delete();
    });
  });
}
