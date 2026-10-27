/// 打卡统计计算。
///
/// 纯函数，不依赖数据库，方便单元测试。
library;

/// 单条打卡项在某个月的统计结果。
class CheckInStats {
  final int completedDays; // 本月实际完成天数
  final int dueDays; // 本月应打卡天数
  final int currentStreak; // 当前连续天数（截至今天）
  final int longestStreak; // 历史最长连续天数

  const CheckInStats({
    required this.completedDays,
    required this.dueDays,
    required this.currentStreak,
    required this.longestStreak,
  });

  /// 月完成率（0~1），应打卡天数为 0 时返回 0。
  double get monthlyRate => dueDays == 0 ? 0 : completedDays / dueDays;
}

/// 打卡统计工具。
class CheckInStatsCalculator {
  /// 计算当前连续天数。
  ///
  /// 从今天开始往回数：若今天已完成则从今天算起，否则从昨天开始往回数；
  /// 遇到第一个未完成日即停止。日期以 `YYYY-MM-DD` 字符串集合表示已完成日。
  static int currentStreak(Set<String> completedDates, DateTime today) {
    int streak = 0;
    var cursor = today;
    // 今天未完成，则从昨天开始判断。
    if (!completedDates.contains(_format(cursor))) {
      cursor = cursor.subtract(const Duration(days: 1));
    }
    while (completedDates.contains(_format(cursor))) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  /// 计算历史最长连续天数。
  static int longestStreak(Set<String> completedDates) {
    if (completedDates.isEmpty) return 0;
    final dates = completedDates.toList()..sort();
    int longest = 1;
    int run = 1;
    for (var i = 1; i < dates.length; i++) {
      final prev = DateTime.parse(dates[i - 1]);
      final cur = DateTime.parse(dates[i]);
      if (cur.difference(prev).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }
    return longest;
  }

  /// 计算某个月的统计。
  ///
  /// - [completedDates]：该打卡项已完成的所有日期集合。
  /// - [startDate]：打卡项开始日期 `YYYY-MM-DD`。
  /// - [archivedAt]：归档日期 `YYYY-MM-DD`，可为 null（未归档）。
  /// - [month]：目标月份的任意一天。
  /// - [today]：今天。
  static CheckInStats monthly({
    required Set<String> completedDates,
    required String startDate,
    required String? archivedAt,
    required DateTime month,
    required DateTime today,
  }) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);

    // 应打卡起始日 = max(start_date, 当月1日)
    final start = DateTime.parse(startDate);
    final dueStart = start.isAfter(firstDay)
        ? start
        : firstDay;

    // 应打卡结束日 = min(当月最后一天, archivedAt-1 或 今天)
    DateTime dueEnd = lastDay;
    if (archivedAt != null) {
      final archived = DateTime.parse(archivedAt).subtract(
        const Duration(days: 1),
      );
      if (archived.isBefore(dueEnd)) dueEnd = archived;
    }
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (todayOnly.isBefore(dueEnd)) dueEnd = todayOnly;

    // 应打卡天数
    final dueDays = dueStart.isAfter(dueEnd)
        ? 0
        : dueEnd.difference(dueStart).inDays + 1;

    // 本月完成天数
    int completedDays = 0;
    for (var d = dueStart; !d.isAfter(dueEnd); d = d.add(const Duration(days: 1))) {
      if (completedDates.contains(_format(d))) completedDays++;
    }

    return CheckInStats(
      completedDays: completedDays,
      dueDays: dueDays,
      currentStreak: currentStreak(completedDates, today),
      longestStreak: longestStreak(completedDates),
    );
  }

  static String _format(DateTime d) {
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
