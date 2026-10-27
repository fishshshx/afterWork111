import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/services/check_in_stats.dart';
import '../models/check_in_item.dart';
import '../models/check_in_record.dart';
import 'app_database_provider.dart';

/// 所有打卡项（含已归档）。
final checkInItemsProvider = FutureProvider<List<CheckInItem>>((ref) async {
  final dao = ref.watch(checkInItemDaoProvider);
  return dao.getAll();
});

/// 启用中的打卡项。
final activeCheckInItemsProvider = FutureProvider<List<CheckInItem>>((ref) async {
  final dao = ref.watch(checkInItemDaoProvider);
  return dao.getActive();
});

/// 某打卡项某天的打卡记录。
final checkInRecordByItemAndDateProvider =
    FutureProvider.family<CheckInRecord?, ({int itemId, String date})>(
  (ref, key) async {
    final dao = ref.watch(checkInRecordDaoProvider);
    return dao.getByItemAndDate(key.itemId, key.date);
  },
);

/// 某打卡项在某个月的统计结果。
final checkInStatsProvider =
    FutureProvider.family<CheckInStats, ({int itemId, DateTime month})>(
  (ref, key) async {
    final itemDao = ref.watch(checkInItemDaoProvider);
    final recordDao = ref.watch(checkInRecordDaoProvider);
    final item = await itemDao.getById(key.itemId);
    if (item == null) {
      return const CheckInStats(
        completedDays: 0,
        dueDays: 0,
        currentStreak: 0,
        longestStreak: 0,
      );
    }
    final completedDates = await recordDao.getCompletedDates(key.itemId);
    return CheckInStatsCalculator.monthly(
      completedDates: completedDates,
      startDate: item.startDate,
      archivedAt: item.archivedAt,
      month: key.month,
      today: DateTime.now(),
    );
  },
);
