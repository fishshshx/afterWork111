import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import 'app_database_provider.dart';

final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final dao = ref.watch(activityDaoProvider);
  return dao.getAll(includeArchived: false);
});

final activitiesByCategoryProvider =
    FutureProvider.family<List<Activity>, int>((ref, categoryId) async {
  final dao = ref.watch(activityDaoProvider);
  return dao.getByCategory(categoryId, includeArchived: false);
});

final activityByIdProvider = FutureProvider.family<Activity?, int>((ref, id) async {
  final dao = ref.watch(activityDaoProvider);
  return dao.getById(id);
});

final archivedActivitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final dao = ref.watch(activityDaoProvider);
  return dao.getAll(includeArchived: true);
});
