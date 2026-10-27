import 'dart:io';

import 'package:after_work/data/app_database.dart';
import 'package:after_work/data/daos/check_in_item_dao.dart';
import 'package:after_work/data/daos/check_in_record_dao.dart';
import 'package:after_work/models/check_in_item.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:test/test.dart';

void main() {
  sqfliteFfiInit();

  late AppDatabase db;
  late CheckInItemDao itemDao;
  late CheckInRecordDao recordDao;
  final testDir = p.join(Directory.systemTemp.path, 'after_work_check_in_test');

  setUp(() async {
    await Directory(testDir).create(recursive: true);
    db = AppDatabase.test(p.join(testDir, 'test.db'), databaseFactoryFfi);
    itemDao = CheckInItemDao(db);
    recordDao = CheckInRecordDao(db);
  });

  tearDown(() async {
    await db.close();
    final f = File(p.join(testDir, 'test.db'));
    if (await f.exists()) await f.delete();
  });

  CheckInItem makeItem({
    required String name,
    String startDate = '2026-10-01',
  }) {
    final now = DateTime.now();
    return CheckInItem(
      name: name,
      startDate: startDate,
      createdAt: now,
      updatedAt: now,
    );
  }

  test('创建打卡项并读取', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    final item = await itemDao.getById(id);
    expect(item, isNotNull);
    expect(item!.name, '早睡');
    expect(item.isEnabled, isTrue);
    expect(item.archivedAt, isNull);
  });

  test('打卡生成记录，同一天重复打卡会更新而非新增', () async {
    final id = await itemDao.insert(makeItem(name: '早起'));
    await recordDao.upsert(itemId: id, date: '2026-10-26', isCompleted: true);

    final all = await recordDao.getByItem(id);
    expect(all.length, 1);

    // 重复 upsert 应更新同一条
    await recordDao.upsert(
      itemId: id,
      date: '2026-10-26',
      isCompleted: false,
    );
    final after = await recordDao.getByItem(id);
    expect(after.length, 1);
    expect(after.first.isCompleted, isFalse);
  });

  test('补打卡过去的日期', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    await recordDao.upsert(itemId: id, date: '2026-10-20', isCompleted: true);
    final rec = await recordDao.getByItemAndDate(id, '2026-10-20');
    expect(rec, isNotNull);
    expect(rec!.isCompleted, isTrue);
  });

  test('归档打卡项后 active 列表不含它，历史记录保留', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    await recordDao.upsert(itemId: id, date: '2026-10-20', isCompleted: true);

    await itemDao.archive(id);

    final active = await itemDao.getActive();
    expect(active.where((e) => e.id == id), isEmpty);

    final all = await itemDao.getAll();
    expect(all.where((e) => e.id == id), isNotEmpty);
    expect(all.firstWhere((e) => e.id == id).archivedAt, isNotNull);

    // 历史记录保留
    final records = await recordDao.getByItem(id);
    expect(records.length, 1);
  });

  test('取消归档恢复启用', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    await itemDao.archive(id);
    await itemDao.unarchive(id);

    final item = await itemDao.getById(id);
    expect(item!.archivedAt, isNull);
    expect(item.isEnabled, isTrue);
  });

  test('硬删除打卡项后记录 item_id 置空', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    await recordDao.upsert(itemId: id, date: '2026-10-20', isCompleted: true);

    await itemDao.delete(id);

    final item = await itemDao.getById(id);
    expect(item, isNull);

    // 记录仍存在，但 item_id 已被外键 SET NULL
    final database = await db.database;
    final rows = await database.query('check_in_records');
    expect(rows.length, 1);
    expect(rows.first['item_id'], isNull);
  });

  test('getCompletedDates 只返回完成日期', () async {
    final id = await itemDao.insert(makeItem(name: '早睡'));
    await recordDao.upsert(itemId: id, date: '2026-10-20', isCompleted: true);
    await recordDao.upsert(itemId: id, date: '2026-10-21', isCompleted: false);
    await recordDao.upsert(itemId: id, date: '2026-10-22', isCompleted: true);

    final dates = await recordDao.getCompletedDates(id);
    expect(dates, {'2026-10-20', '2026-10-22'});
  });
}
