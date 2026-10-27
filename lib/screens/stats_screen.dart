import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/stats_models.dart';
import '../providers/check_in_provider.dart';
import '../providers/stats_provider.dart';

class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final summaryAsync = ref.watch(monthSummaryProvider(month));
    final activityStatsAsync = ref.watch(activityStatsProvider(month));
    final categoryStatsAsync = ref.watch(categoryStatsProvider(month));

    return Scaffold(
      appBar: AppBar(
        title: const Text('统计'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _MonthSwitcher(month: month),
          const SizedBox(height: 16),
          summaryAsync.when(
            data: (summary) => _SummaryCard(
              totalMinutes: summary.totalMinutes,
              totalCount: summary.totalCount,
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => Text('概览加载失败: $e'),
          ),
          const SizedBox(height: 24),
          Text(
            '分类占比',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          categoryStatsAsync.when(
            data: (stats) => _CategoryPieChart(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('分类统计加载失败: $e'),
          ),
          const SizedBox(height: 24),
          Text(
            '活动排行',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          activityStatsAsync.when(
            data: (stats) => _ActivityRanking(stats: stats),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Text('活动排行加载失败: $e'),
          ),
          const SizedBox(height: 24),
          Text(
            '打卡统计',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const _CheckInStatsSection(),
        ],
      ),
    );
  }
}

class _MonthSwitcher extends ConsumerWidget {
  final DateTime month;

  const _MonthSwitcher({required this.month});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: () {
            ref.read(statsMonthProvider.notifier).state = DateTime(
              month.year,
              month.month - 1,
              1,
            );
          },
        ),
        Text(
          DateFormat('yyyy年M月').format(month),
          style: Theme.of(context).textTheme.titleLarge,
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: () {
            ref.read(statsMonthProvider.notifier).state = DateTime(
              month.year,
              month.month + 1,
              1,
            );
          },
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int totalMinutes;
  final int totalCount;

  const _SummaryCard({required this.totalMinutes, required this.totalCount});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _SummaryItem(label: '记录次数', value: '$totalCount 次'),
            _SummaryItem(label: '总时长', value: '$totalMinutes 分钟'),
          ],
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CategoryPieChart extends StatelessWidget {
  final List<CategoryStat> stats;

  const _CategoryPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    if (stats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('本月还没有记录'),
        ),
      );
    }

    final totalMinutes = stats.fold<int>(0, (sum, s) => sum + s.totalMinutes);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SizedBox(
              height: 200,
              child: PieChart(
                PieChartData(
                  sections: stats.map((s) {
                    final percent = totalMinutes == 0
                        ? 0.0
                        : s.totalMinutes / totalMinutes;
                    return PieChartSectionData(
                      value: s.totalMinutes.toDouble(),
                      title:
                          '${s.categoryName}\n${(percent * 100).round()}%',
                      radius: 80,
                      color: _parseColor(s.categoryColor),
                      titleStyle: const TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    );
                  }).toList(),
                  sectionsSpace: 2,
                  centerSpaceRadius: 30,
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...stats.map((s) {
              final percent =
                  totalMinutes == 0 ? 0.0 : s.totalMinutes / totalMinutes;
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 8,
                  backgroundColor: _parseColor(s.categoryColor),
                ),
                title: Text(s.categoryName),
                subtitle: Text('${s.count} 次'),
                trailing: Text(
                  '${s.totalMinutes} 分钟 (${(percent * 100).round()}%)',
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('FF');
      buffer.write(hex.replaceFirst('#', ''));
    } else if (hex.length == 9) {
      buffer.write(hex.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _ActivityRanking extends ConsumerWidget {
  final List<ActivityStat> stats;

  const _ActivityRanking({required this.stats});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (stats.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('本月还没有活动记录'),
        ),
      );
    }

    return Column(
      children: stats.map((s) {
        return _ActivityRankTile(stat: s);
      }).toList(),
    );
  }
}

class _ActivityRankTile extends ConsumerWidget {
  final ActivityStat stat;

  const _ActivityRankTile({required this.stat});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundColor: _parseColor(stat.categoryColor),
          child: Text(
            stat.activityName.characters.first,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(stat.activityName),
        subtitle: Text('${stat.categoryName} · ${stat.count} 次'),
        trailing: Text(
          '${stat.totalMinutes} 分钟',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        children: [
          _ActivityTrendChart(
            activityId: stat.activityId,
            activityName: stat.activityName,
          ),
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('FF');
      buffer.write(hex.replaceFirst('#', ''));
    } else if (hex.length == 9) {
      buffer.write(hex.replaceFirst('#', ''));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _ActivityTrendChart extends ConsumerWidget {
  final int activityId;
  final String activityName;

  const _ActivityTrendChart({
    required this.activityId,
    required this.activityName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final dailyAsync = ref.watch(
      activityDailyProvider((activityId: activityId, month: month)),
    );

    return Padding(
      padding: const EdgeInsets.all(16),
      child: dailyAsync.when(
        data: (points) {
          if (points.isEmpty) return const Text('暂无按日数据');
          return SizedBox(
            height: 160,
            child: BarChart(
              BarChartData(
                barGroups: points.asMap().entries.map((entry) {
                  final idx = entry.key;
                  final p = entry.value;
                  return BarChartGroupData(
                    x: idx,
                    barRods: [
                      BarChartRodData(
                        toY: p.minutes.toDouble(),
                        color: Colors.blueAccent,
                        width: 12,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ],
                  );
                }).toList(),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 32,
                      getTitlesWidget: (value, meta) => Text(
                        value.toInt().toString(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final idx = value.toInt();
                        if (idx < 0 || idx >= points.length) {
                          return const SizedBox.shrink();
                        }
                        final date = DateTime.parse(points[idx].date);
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${date.day}',
                            style: const TextStyle(fontSize: 10),
                          ),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Text('趋势加载失败: $e'),
      ),
    );
  }
}

class _CheckInStatsSection extends ConsumerWidget {
  const _CheckInStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeCheckInItemsProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Card(
            child: ListTile(title: Text('还没有打卡项')),
          );
        }
        return Column(
          children: items.map((item) {
            return _CheckInMonthStat(itemId: item.id!, itemName: item.name);
          }).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('打卡统计加载失败: $e'),
    );
  }
}

class _CheckInMonthStat extends ConsumerWidget {
  final int itemId;
  final String itemName;

  const _CheckInMonthStat({required this.itemId, required this.itemName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = ref.watch(statsMonthProvider);
    final statsAsync = ref.watch(
      checkInStatsProvider((itemId: itemId, month: month)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: statsAsync.when(
        data: (stats) {
          return ListTile(
            title: Text(itemName),
            subtitle: LinearProgressIndicator(
              value: stats.monthlyRate.clamp(0.0, 1.0),
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${stats.completedDays}/${stats.dueDays} 天'),
                Text(
                  '连续 ${stats.currentStreak} 天',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          );
        },
        loading: () => const ListTile(
          title: Text('加载中'),
          leading: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (e, s) => ListTile(
          title: Text(itemName),
          subtitle: Text('统计失败: $e'),
        ),
      ),
    );
  }
}
