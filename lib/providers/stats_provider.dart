import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats_models.dart';
import 'app_database_provider.dart';

/// 当前统计月份（用于页面切换）。默认本月。
final statsMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, 1);
});

/// 某月各活动统计。
final activityStatsProvider =
    FutureProvider.family<List<ActivityStat>, DateTime>((ref, month) async {
  final dao = ref.watch(statsDaoProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  return dao.getActivityStats(start, end);
});

/// 某月各分类统计。
final categoryStatsProvider =
    FutureProvider.family<List<CategoryStat>, DateTime>((ref, month) async {
  final dao = ref.watch(statsDaoProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  return dao.getCategoryStats(start, end);
});

/// 某月某活动的按天趋势。
final activityDailyProvider = FutureProvider.family<
  List<ActivityDailyPoint>,
  ({int activityId, DateTime month})
>((ref, key) async {
  final dao = ref.watch(statsDaoProvider);
  final start = _monthStart(key.month);
  final end = _monthEnd(key.month);
  return dao.getActivityDaily(key.activityId, start, end);
});

/// 某月总时长与总次数。
final monthSummaryProvider =
    FutureProvider.family<({int totalMinutes, int totalCount}), DateTime>((
  ref,
  month,
) async {
  final dao = ref.watch(statsDaoProvider);
  final start = _monthStart(month);
  final end = _monthEnd(month);
  return dao.getMonthSummary(start, end);
});

String _monthStart(DateTime month) =>
    '${month.year.toString().padLeft(4, '0')}-${month.month.toString().padLeft(2, '0')}-01';

String _monthEnd(DateTime month) {
  final lastDay = DateTime(month.year, month.month + 1, 0);
  return '${lastDay.year.toString().padLeft(4, '0')}-${lastDay.month.toString().padLeft(2, '0')}-${lastDay.day.toString().padLeft(2, '0')}';
}
