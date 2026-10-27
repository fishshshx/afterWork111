import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/record_with_activity.dart';
import 'activity_provider.dart';
import 'app_database_provider.dart';
import 'category_provider.dart';

final recordsProvider = FutureProvider<List<RecordWithActivity>>((ref) async {
  final dao = ref.watch(recordDaoProvider);
  return dao.getAll();
});

final recordsByDateProvider =
    FutureProvider.family<List<RecordWithActivity>, String>((ref, date) async {
  final dao = ref.watch(recordDaoProvider);
  return dao.getByDate(date);
});

final recordByIdProvider = FutureProvider.family<RecordWithActivity?, int>(
  (ref, id) async {
    final dao = ref.watch(recordDaoProvider);
    final record = await dao.getById(id);
    if (record == null) return null;

    final activity = await ref.watch(activityByIdProvider(record.activityId).future);
    if (activity == null) throw Exception('关联活动不存在');
    final categories = await ref.watch(categoriesProvider.future);
    final category = categories.firstWhere((c) => c.id == activity.categoryId);

    return RecordWithActivity(
      record: record,
      activity: activity,
      category: category,
    );
  },
);
