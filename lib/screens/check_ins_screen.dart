import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/check_in_item.dart';
import '../providers/app_database_provider.dart';
import '../providers/check_in_provider.dart';

class CheckInsScreen extends ConsumerWidget {
  const CheckInsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeCheckInItemsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('打卡'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/check-ins/manage'),
          ),
        ],
      ),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('还没有打卡项'),
                  Text('点右上角设置，新建打卡项'),
                ],
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                '今日打卡',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _CheckInTile(item: item)),
              const SizedBox(height: 24),
              Text(
                '本月统计',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ...items.map((item) => _CheckInStatsCard(item: item)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
  }
}

/// 单个打卡项卡片：显示今日状态、连续天数，可打卡/补打卡。
class _CheckInTile extends ConsumerWidget {
  final CheckInItem item;

  const _CheckInTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final recordAsync = ref.watch(
      checkInRecordByItemAndDateProvider((itemId: item.id!, date: today)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: recordAsync.when(
        data: (record) {
          final done = record?.isCompleted ?? false;
          return ListTile(
            leading: Icon(
              done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: done ? Colors.green : Colors.grey,
              size: 32,
            ),
            title: Text(item.name),
            subtitle: const Text('每天一次'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.history),
                  tooltip: '补打卡',
                  onPressed: () => _showBackfillDialog(context, ref),
                ),
                IconButton(
                  icon: Icon(done ? Icons.undo : Icons.done),
                  color: done ? Colors.orange : Colors.green,
                  onPressed: () async {
                    final recordDao = ref.read(checkInRecordDaoProvider);
                    await recordDao.upsert(
                      itemId: item.id!,
                      date: today,
                      isCompleted: !done,
                    );
                    ref.invalidate(checkInRecordByItemAndDateProvider);
                    ref.invalidate(checkInStatsProvider);
                  },
                ),
              ],
            ),
          );
        },
        loading: () => const ListTile(
          leading: SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          title: Text('加载中'),
        ),
        error: (err, stack) => ListTile(
          leading: const Icon(Icons.error),
          title: Text(item.name),
          subtitle: Text('加载失败: $err'),
        ),
      ),
    );
  }

  Future<void> _showBackfillDialog(BuildContext context, WidgetRef ref) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    final date = DateFormat('yyyy-MM-dd').format(picked);

    final recordDao = ref.read(checkInRecordDaoProvider);
    await recordDao.upsert(itemId: item.id!, date: date, isCompleted: true);
    ref.invalidate(checkInRecordByItemAndDateProvider);
    ref.invalidate(checkInStatsProvider);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已补打卡 $date')),
      );
    }
  }
}

/// 单个打卡项本月统计卡片。
class _CheckInStatsCard extends ConsumerWidget {
  final CheckInItem item;

  const _CheckInStatsCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final month = DateTime.now();
    final statsAsync = ref.watch(
      checkInStatsProvider((itemId: item.id!, month: month)),
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: statsAsync.when(
        data: (stats) {
          final percent = (stats.monthlyRate * 100).round();
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text('${stats.completedDays}/${stats.dueDays} 天'),
                  ],
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: stats.monthlyRate.clamp(0.0, 1.0),
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(4),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('本月完成率 $percent%'),
                    Text('连续 ${stats.currentStreak} 天 · 最长 ${stats.longestStreak} 天'),
                  ],
                ),
              ],
            ),
          );
        },
        loading: () => const ListTile(
          title: Text('统计加载中'),
          leading: CircularProgressIndicator(strokeWidth: 2),
        ),
        error: (err, stack) => ListTile(
          title: Text(item.name),
          subtitle: Text('统计失败: $err'),
        ),
      ),
    );
  }
}
