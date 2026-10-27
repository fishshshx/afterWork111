import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/check_in_item.dart';
import '../providers/app_database_provider.dart';
import '../providers/check_in_provider.dart';

/// 打卡项管理页：新建、编辑、归档/取消归档、硬删除。
class CheckInManageScreen extends ConsumerWidget {
  const CheckInManageScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(checkInItemsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('打卡项管理')),
      body: itemsAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('还没有打卡项'));
          }
          return ListView(
            children: [
              ...items.map((item) => _ItemTile(item: item)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/check-ins/edit'),
        child: const Icon(Icons.add),
      ),
    );
  }
}

class _ItemTile extends ConsumerWidget {
  final CheckInItem item;

  const _ItemTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final archived = item.archivedAt != null;
    return ListTile(
      leading: Icon(
        archived ? Icons.archive : Icons.check_circle_outline,
        color: archived ? Colors.grey : Colors.green,
      ),
      title: Text(item.name),
      subtitle: Text(
        archived ? '已归档' : '启用中 · 每天一次',
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (value) => _handleAction(context, ref, value),
        itemBuilder: (context) => [
          const PopupMenuItem(
            value: 'edit',
            child: Text('编辑'),
          ),
          PopupMenuItem(
            value: archived ? 'unarchive' : 'archive',
            child: Text(archived ? '取消归档' : '归档'),
          ),
          const PopupMenuItem(
            value: 'delete',
            child: Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
      onTap: () => context.push('/check-ins/edit?id=${item.id}'),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    String action,
  ) async {
    final dao = ref.read(checkInItemDaoProvider);
    switch (action) {
      case 'edit':
        context.push('/check-ins/edit?id=${item.id}');
      case 'archive':
        await dao.archive(item.id!);
      case 'unarchive':
        await dao.unarchive(item.id!);
      case 'delete':
        final confirmed = await _confirmDelete(context);
        if (!confirmed) return;
        await dao.delete(item.id!);
    }
    ref.invalidate(checkInItemsProvider);
    ref.invalidate(activeCheckInItemsProvider);
    ref.invalidate(checkInStatsProvider);
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除打卡项'),
        content: Text('确定删除「${item.name}」吗？历史打卡记录会保留（关联置空）。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
