import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/record_with_activity.dart';
import '../providers/app_database_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/record_provider.dart';

class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recordsAsync = ref.watch(recordsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('记录'),
      ),
      body: recordsAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(child: Text('还没有记录。完成计划后会自动生成，也可以直接补录。'));
          }
          return _RecordList(records: records);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/records/add'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _RecordList extends StatelessWidget {
  final List<RecordWithActivity> records;

  const _RecordList({required this.records});

  @override
  Widget build(BuildContext context) {
    final grouped = _groupByDate(records);
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return ListView.builder(
      itemCount: dates.length,
      itemBuilder: (context, index) {
        final date = dates[index];
        final dateRecords = grouped[date]!;
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
            ...dateRecords.map((item) => _RecordTile(item: item)),
          ],
        );
      },
    );
  }

  Map<String, List<RecordWithActivity>> _groupByDate(
    List<RecordWithActivity> records,
  ) {
    final map = <String, List<RecordWithActivity>>{};
    for (final item in records) {
      map.putIfAbsent(item.record.recordDate, () => []).add(item);
    }
    return map;
  }
}

class _RecordTile extends ConsumerWidget {
  final RecordWithActivity item;

  const _RecordTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final record = item.record;

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
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('${item.category.name} · ${record.actualMinutes} 分钟'),
                if (record.photoPaths.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.photo_size_select_actual,
                    size: 14,
                    color: Theme.of(context).hintColor,
                  ),
                  const SizedBox(width: 2),
                  Text(
                    '${record.photoPaths.length}',
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ],
              ],
            ),
            if (record.note != null && record.note!.isNotEmpty)
              Text(
                record.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _confirmDelete(context, ref),
        ),
        onTap: () => context.push('/records/edit?id=${record.id}'),
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

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除记录'),
            content: Text(
              item.record.planId != null
                  ? '删除记录后，关联计划会变回待进行状态。确定删除吗？'
                  : '确定删除这条记录吗？',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('删除'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    await ref.read(recordDaoProvider).delete(item.record.id!);
    ref.invalidate(recordsProvider);
    ref.invalidate(recordsByDateProvider);
    ref.invalidate(plansProvider);
    ref.invalidate(plansByDateProvider);
  }
}
