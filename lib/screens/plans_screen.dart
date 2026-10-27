import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/plan_with_activity.dart';
import '../providers/app_database_provider.dart';
import '../providers/plan_provider.dart';

class PlansScreen extends ConsumerWidget {
  const PlansScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(plansProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计划'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/plans/add'),
          ),
        ],
      ),
      body: plansAsync.when(
        data: (plans) {
          if (plans.isEmpty) {
            return const Center(child: Text('还没有计划，点击右上角添加。'));
          }
          return _PlanList(
            plans: plans,
            onRefresh: () => ref.invalidate(plansProvider),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/plans/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _PlanList extends ConsumerWidget {
  final List<PlanWithActivity> plans;
  final VoidCallback onRefresh;

  const _PlanList({required this.plans, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final grouped = _groupByDate(plans);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final datePlans = grouped[date]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                DateFormat('yyyy-MM-dd EEEE', 'zh_CN').format(DateTime.parse(date)),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ...datePlans.map((item) => _PlanTile(item: item)),
          ],
        );
      },
    );
  }

  Map<String, List<PlanWithActivity>> _groupByDate(
    List<PlanWithActivity> plans,
  ) {
    final map = <String, List<PlanWithActivity>>{};
    for (final item in plans) {
      map.putIfAbsent(item.plan.planDate, () => []).add(item);
    }
    return map;
  }
}

class _PlanTile extends ConsumerWidget {
  final PlanWithActivity item;

  const _PlanTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = item.plan;
    final isPending = plan.status == 'pending';

    Color statusColor;
    String statusText;
    switch (plan.status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = '已完成';
      case 'skipped':
        statusColor = Colors.orange;
        statusText = '已跳过';
      case 'cancelled':
        statusColor = Colors.grey;
        statusText = '已取消';
      default:
        statusColor = Colors.blue;
        statusText = '待进行';
    }

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
        trailing: Chip(
          label: Text(statusText),
          backgroundColor: statusColor.withAlpha(30),
          labelStyle: TextStyle(color: statusColor),
          side: BorderSide(color: statusColor),
        ),
        onTap: () => context.push('/plans/edit?id=${plan.id}'),
        onLongPress: isPending ? () => _showActions(context, ref) : null,
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

  void _showActions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.check_circle, color: Colors.green),
              title: const Text('完成计划'),
              onTap: () {
                Navigator.of(context).pop();
                context.push('/plans/complete?id=${item.plan.id}');
              },
            ),
            ListTile(
              leading: const Icon(Icons.skip_next, color: Colors.orange),
              title: const Text('跳过'),
              onTap: () async {
                Navigator.of(context).pop();
                await ref
                    .read(planRecordServiceProvider)
                    .markSkipped(item.plan.id!);
                ref.invalidate(plansProvider);
                ref.invalidate(plansByDateProvider);
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
                ref.invalidate(plansProvider);
                ref.invalidate(plansByDateProvider);
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
