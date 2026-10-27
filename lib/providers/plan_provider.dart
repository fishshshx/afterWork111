import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/plan_with_activity.dart';
import 'activity_provider.dart';
import 'app_database_provider.dart';
import 'category_provider.dart';

final plansProvider = FutureProvider<List<PlanWithActivity>>((ref) async {
  final dao = ref.watch(planDaoProvider);
  return dao.getAll();
});

final plansByDateProvider = FutureProvider.family<List<PlanWithActivity>, String>(
  (ref, date) async {
    final dao = ref.watch(planDaoProvider);
    return dao.getByDate(date);
  },
);

final planByIdProvider = FutureProvider.family<PlanWithActivity?, int>(
  (ref, id) async {
    final dao = ref.watch(planDaoProvider);
    final plan = await dao.getById(id);
    if (plan == null) return null;
    final activities = await ref.watch(activitiesProvider.future);
    final categories = await ref.watch(categoriesProvider.future);
    final activity = activities.firstWhere((a) => a.id == plan.activityId);
    final category = categories.firstWhere((c) => c.id == activity.categoryId);
    return PlanWithActivity(
      plan: plan,
      activity: activity,
      category: category,
    );
  },
);
