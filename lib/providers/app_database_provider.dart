import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/app_database.dart';
import '../data/daos/activity_dao.dart';
import '../data/daos/category_dao.dart';
import '../data/daos/check_in_item_dao.dart';
import '../data/daos/check_in_record_dao.dart';
import '../data/daos/plan_dao.dart';
import '../data/daos/record_dao.dart';
import '../data/daos/stats_dao.dart';
import '../data/services/data_export_service.dart';
import '../data/services/photo_file_service.dart';
import '../data/services/plan_record_service.dart';

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  return AppDatabase();
});

final categoryDaoProvider = Provider<CategoryDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CategoryDao(db);
});

final activityDaoProvider = Provider<ActivityDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return ActivityDao(db);
});

final planDaoProvider = Provider<PlanDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PlanDao(db);
});

final photoFileServiceProvider = Provider<PhotoFileService>((ref) {
  throw UnimplementedError(
    'photoFileServiceProvider must be overridden in ProviderScope before use.',
  );
});

final recordDaoProvider = Provider<RecordDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final photoService = ref.watch(photoFileServiceProvider);
  return RecordDao(db, photoServiceFuture: Future.value(photoService));
});

final planRecordServiceProvider = Provider<PlanRecordService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return PlanRecordService(db);
});

final checkInItemDaoProvider = Provider<CheckInItemDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CheckInItemDao(db);
});

final checkInRecordDaoProvider = Provider<CheckInRecordDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return CheckInRecordDao(db);
});

final statsDaoProvider = Provider<StatsDao>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return StatsDao(db);
});

final dataExportServiceProvider = Provider<DataExportService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final photoService = ref.watch(photoFileServiceProvider);
  return DataExportService(db, photoService);
});
