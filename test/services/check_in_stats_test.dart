import 'package:after_work/data/services/check_in_stats.dart';
import 'package:test/test.dart';

void main() {
  group('currentStreak', () {
    final today = DateTime(2026, 10, 26);

    test('今天已完成，从今天开始连续计算', () {
      final dates = {'2026-10-26', '2026-10-25', '2026-10-24'};
      expect(CheckInStatsCalculator.currentStreak(dates, today), 3);
    });

    test('今天未完成，从昨天开始计算', () {
      final dates = {'2026-10-25', '2026-10-24'};
      expect(CheckInStatsCalculator.currentStreak(dates, today), 2);
    });

    test('今天和昨天都未完成，连续为 0', () {
      final dates = {'2026-10-24'};
      expect(CheckInStatsCalculator.currentStreak(dates, today), 0);
    });

    test('中间断开则中断', () {
      final dates = {'2026-10-26', '2026-10-25', '2026-10-23'};
      expect(CheckInStatsCalculator.currentStreak(dates, today), 2);
    });
  });

  group('longestStreak', () {
    test('空集合为 0', () {
      expect(CheckInStatsCalculator.longestStreak(<String>{}), 0);
    });

    test('最长连续段', () {
      final dates = {
        '2026-10-01',
        '2026-10-02',
        '2026-10-03',
        '2026-10-10',
        '2026-10-11',
      };
      expect(CheckInStatsCalculator.longestStreak(dates), 3);
    });
  });

  group('monthly', () {
    final today = DateTime(2026, 10, 26);
    final month = DateTime(2026, 10, 1);

    test('整月应打卡天数按今天截断', () {
      final stats = CheckInStatsCalculator.monthly(
        completedDates: {'2026-10-01', '2026-10-02'},
        startDate: '2026-10-01',
        archivedAt: null,
        month: month,
        today: today,
      );
      expect(stats.dueDays, 26); // 10月1日 ~ 10月26日
      expect(stats.completedDays, 2);
    });

    test('start_date 晚于当月1日，应打卡天数从 start_date 起算', () {
      final stats = CheckInStatsCalculator.monthly(
        completedDates: {'2026-10-10', '2026-10-11'},
        startDate: '2026-10-10',
        archivedAt: null,
        month: month,
        today: today,
      );
      expect(stats.dueDays, 17); // 10月10日 ~ 10月26日
      expect(stats.completedDays, 2);
    });

    test('归档日期截断应打卡天数', () {
      final stats = CheckInStatsCalculator.monthly(
        completedDates: {'2026-10-01', '2026-10-05'},
        startDate: '2026-10-01',
        archivedAt: '2026-10-06',
        month: month,
        today: today,
      );
      // 归档于 10月6日，则有效到 10月5日，应打卡 5 天
      expect(stats.dueDays, 5);
      expect(stats.completedDays, 2);
    });

    test('start_date 晚于当月最后一天则应打卡 0 天', () {
      final stats = CheckInStatsCalculator.monthly(
        completedDates: const {},
        startDate: '2026-11-01',
        archivedAt: null,
        month: month,
        today: today,
      );
      expect(stats.dueDays, 0);
      expect(stats.monthlyRate, 0);
    });

    test('月完成率计算', () {
      final stats = CheckInStatsCalculator.monthly(
        completedDates: {'2026-10-01'},
        startDate: '2026-10-01',
        archivedAt: null,
        month: month,
        today: today,
      );
      expect(stats.monthlyRate, closeTo(1 / 26, 0.0001));
    });
  });
}
