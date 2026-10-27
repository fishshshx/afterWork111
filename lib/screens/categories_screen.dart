import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/category.dart';
import '../providers/app_database_provider.dart';
import '../providers/category_provider.dart';

class CategoriesScreen extends ConsumerWidget {
  const CategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('分类管理')),
      body: categoriesAsync.when(
        data: (categories) {
          if (categories.isEmpty) {
            return const Center(child: Text('暂无分类'));
          }
          return ReorderableListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: categories.length,
            onReorderItem: (int oldIndex, int newIndex) async {
              final moved = categories.removeAt(oldIndex);
              categories.insert(newIndex, moved);
              final dao = ref.read(categoryDaoProvider);
              await dao.updateSortOrder(List.from(categories));
              ref.invalidate(categoriesProvider);
            },
            itemBuilder: (context, index) {
              final category = categories[index];
              return _CategoryTile(
                key: ValueKey(category.id),
                category: category,
                onEdit: () => _showEditDialog(context, ref, category),
                onDelete: () => _confirmDelete(context, ref, category),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败：$err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _showAddDialog(BuildContext context, WidgetRef ref) async {
    await showDialog(
      context: context,
      builder: (context) => const _CategoryDialog(),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    await showDialog(
      context: context,
      builder: (context) => _CategoryDialog(category: category),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Category category,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除分类'),
          content: Text('确定删除分类「${category.name}」吗？若该分类下存在活动将无法删除。'),
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
        );
      },
    );

    if (confirmed == true && context.mounted) {
      try {
        final dao = ref.read(categoryDaoProvider);
        await dao.delete(category.id!);
        ref.invalidate(categoriesProvider);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(e.toString())),
          );
        }
      }
    }
  }
}

class _CategoryTile extends StatelessWidget {
  final Category category;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CategoryTile({
    required Key key,
    required this.category,
    required this.onEdit,
    required this.onDelete,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(category.color);

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: color,
        radius: 16,
      ),
      title: Text(category.name),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: onEdit,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('FF');
      buffer.write(hex.substring(1));
    } else {
      buffer.write(hex.substring(1));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}

class _CategoryDialog extends ConsumerStatefulWidget {
  final Category? category;

  const _CategoryDialog({this.category});

  @override
  ConsumerState<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends ConsumerState<_CategoryDialog> {
  late final TextEditingController _nameController;
  late String _selectedColor;

  final _presetColors = [
    '#FF5252',
    '#FFAB40',
    '#FFD740',
    '#69F0AE',
    '#40C4FF',
    '#448AFF',
    '#7C4DFF',
    '#E040FB',
    '#FF4081',
    '#BDBDBD',
  ];

  bool get _isEditing => widget.category != null;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.category?.name ?? '');
    _selectedColor = widget.category?.color ?? _presetColors.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? '编辑分类' : '新增分类'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '分类名称',
                hintText: '例如：运动',
              ),
              autofocus: true,
            ),
            const SizedBox(height: 16),
            const Text('颜色'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children:
                  _presetColors.map((color) {
                    final isSelected = color == _selectedColor;
                    return InkWell(
                      onTap: () {
                        setState(() {
                          _selectedColor = color;
                        });
                      },
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _hexToColor(color),
                          shape: BoxShape.circle,
                          border:
                              isSelected
                                  ? Border.all(
                                    color: Theme.of(context).colorScheme.primary,
                                    width: 3,
                                  )
                                  : null,
                        ),
                      ),
                    );
                  }).toList(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: _save,
          child: const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      return;
    }

    final now = DateTime.now();
    final dao = ref.read(categoryDaoProvider);

    if (_isEditing) {
      final updated = widget.category!.copyWith(
        name: name,
        color: _selectedColor,
        updatedAt: now,
      );
      await dao.update(updated);
    } else {
      final category = Category(
        name: name,
        color: _selectedColor,
        createdAt: now,
        updatedAt: now,
      );
      await dao.insert(category);
    }

    ref.invalidate(categoriesProvider);
    if (mounted) Navigator.of(context).pop();
  }

  Color _hexToColor(String hex) {
    final buffer = StringBuffer();
    if (hex.length == 7) {
      buffer.write('FF');
      buffer.write(hex.substring(1));
    } else {
      buffer.write(hex.substring(1));
    }
    return Color(int.parse(buffer.toString(), radix: 16));
  }
}
