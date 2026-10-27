import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/check_in_item.dart';
import '../models/plan_with_activity.dart';
import '../models/record_with_activity.dart';
import '../providers/app_database_provider.dart';
import '../providers/check_in_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/record_provider.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final plansAsync = ref.watch(plansByDateProvider(today));
    final recordsAsync = ref.watch(recordsByDateProvider(today));

    return Scaffold(
      appBar: AppBar(
        title: const Text('今天'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSectionTitle(context, '今日计划'),
          const SizedBox(height: 8),
          plansAsync.when(
            data: (plans) => _PlanSection(
              plans: plans,
              onChanged: () {
                ref.invalidate(plansByDateProvider(today));
                ref.invalidate(plansProvider);
                ref.invalidate(recordsByDateProvider(today));
                ref.invalidate(recordsProvider);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('加载计划失败: $err'),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '今日记录'),
          const SizedBox(height: 8),
          recordsAsync.when(
            data: (records) => _RecordSection(
              records: records,
              onChanged: () {
                ref.invalidate(recordsByDateProvider(today));
                ref.invalidate(recordsProvider);
                ref.invalidate(plansByDateProvider(today));
                ref.invalidate(plansProvider);
              },
            ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => Text('加载记录失败: $err'),
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(context, '今日打卡'),
          const SizedBox(height: 8),
          const _TodayCheckInSection(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showQuickAddMenu(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Future<void> _showQuickAddMenu(BuildContext context) async {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.event_note),
              title: const Text('新建计划'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/plans/add');
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_note),
              title: const Text('补录记录'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/records/add');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanSection extends StatelessWidget {
  final List<PlanWithActivity> plans;
  final VoidCallback onChanged;

  const _PlanSection({required this.plans, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    if (plans.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('没有今日计划'),
          subtitle: Text('点击右下角添加'),
        ),
      );
    }

    return Column(
      children:
          plans.map((item) {
            return _TodayPlanTile(
              item: item,
              onChanged: onChanged,
            );
          }).toList(),
    );
  }
}

class _TodayPlanTile extends ConsumerWidget {
  final PlanWithActivity item;
  final VoidCallback onChanged;

  const _TodayPlanTile({required this.item, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = item.plan;
    final isPending = plan.status == 'pending';

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _parseColor(item.category.color),
          child: Text(
            item.activity.name.characters.first,
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(item.activity.name),
        subtitle: Text(
          '${item.category.name}${plan.planTime != null ? ' · ${plan.planTime}' : ''}${plan.estimatedMinutes != null ? ' · 预计 ${plan.estimatedMinutes} 分钟' : ''}',
        ),
        trailing:
            isPending
                ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle,
                          color: Colors.green),
                      onPressed: () {
                        context.push('/plans/complete?id=${plan.id}');
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.more_vert),
                      onPressed: () => _showPlanActions(context, ref),
                    ),
                  ],
                )
                : _StatusChip(status: plan.status),
        onTap: () => context.push('/plans/edit?id=${plan.id}'),
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

  Future<void> _showPlanActions(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.skip_next, color: Colors.orange),
              title: const Text('跳过'),
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(planRecordServiceProvider)
                    .markSkipped(item.plan.id!);
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.cancel, color: Colors.grey),
              title: const Text('取消'),
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(planRecordServiceProvider)
                    .markCancelled(item.plan.id!);
                onChanged();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/plans/edit?id=${item.plan.id}');
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    switch (status) {
      case 'completed':
        color = Colors.green;
        text = '已完成';
      case 'skipped':
        color = Colors.orange;
        text = '已跳过';
      case 'cancelled':
        color = Colors.grey;
        text = '已取消';
      default:
        color = Colors.blue;
        text = '待进行';
    }
    return Chip(
      label: Text(text),
      backgroundColor: color.withAlpha(30),
      labelStyle: TextStyle(color: color),
      side: BorderSide(color: color),
    );
  }
}

class _RecordSection extends ConsumerWidget {
  final List<RecordWithActivity> records;
  final VoidCallback onChanged;

  const _RecordSection({required this.records, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (records.isEmpty) {
      return const Card(
        child: ListTile(
          title: Text('还没有今日记录'),
          subtitle: Text('完成计划后会自动生成'),
        ),
      );
    }

    return Column(
      children:
          records.map((item) {
            return Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: _parseColor(item.category.color),
                  child: Text(
                    item.activity.name.characters.first,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(item.activity.name),
                subtitle: Text(
                  '${item.category.name} · ${item.record.actualMinutes} 分钟',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ref
                        .read(recordDaoProvider)
                        .delete(item.record.id!);
                    onChanged();
                  },
                ),
              ),
            );
          }).toList(),
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

/// 今日打卡区块：列出启用中的打卡项，支持一键打卡/取消。
class _TodayCheckInSection extends ConsumerWidget {
  const _TodayCheckInSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(activeCheckInItemsProvider);

    return itemsAsync.when(
      data: (items) {
        if (items.isEmpty) {
          return const Card(
            child: ListTile(
              title: Text('还没有打卡项'),
              subtitle: Text('去打卡页新建'),
            ),
          );
        }
        return Column(
          children: items.map((item) => _TodayCheckInTile(item: item)).toList(),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Text('加载打卡失败: $err'),
    );
  }
}

class _TodayCheckInTile extends ConsumerWidget {
  final CheckInItem item;

  const _TodayCheckInTile({required this.item});

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
            ),
            title: Text(item.name),
            trailing: IconButton(
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
          );
        },
        loading: () => const ListTile(
          title: Text('加载中'),
          leading: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
        error: (err, stack) => ListTile(
          title: Text(item.name),
          subtitle: Text('加载失败: $err'),
        ),
      ),
    );
  }
}
