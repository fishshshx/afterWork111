import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/category.dart';
import '../providers/activity_provider.dart';
import '../providers/app_database_provider.dart';
import '../providers/category_provider.dart';

/// 底部弹出的活动选择器。
/// 支持按分类筛选、新建活动；归档活动不在默认列表中显示。
class ActivitySelector extends ConsumerStatefulWidget {
  final void Function(Activity activity) onSelected;

  const ActivitySelector({super.key, required this.onSelected});

  @override
  ConsumerState<ActivitySelector> createState() => _ActivitySelectorState();
}

class _ActivitySelectorState extends ConsumerState<ActivitySelector> {
  int? _selectedCategoryId;

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(categoriesProvider);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: categoriesAsync.when(
          data: (categories) {
            if (categories.isEmpty) {
              return const Center(
                child: Text('没有分类，请先在设置中创建分类。'),
              );
            }
            if (_selectedCategoryId == null ||
                !categories.any((c) => c.id == _selectedCategoryId)) {
              _selectedCategoryId = categories.first.id;
            }
            final categoryMap = {
              for (final c in categories) if (c.id != null) c.id!: c,
            };
            final activitiesAsync = ref.watch(
              activitiesByCategoryProvider(_selectedCategoryId!),
            );

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '选择活动',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    TextButton(
                      onPressed: () => _showCreateActivityDialog(categories),
                      child: const Text('新建活动'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: categories.map((category) {
                    final selected = _selectedCategoryId == category.id;
                    return ChoiceChip(
                      label: Text(category.name),
                      selected: selected,
                      onSelected: (_) {
                        setState(() {
                          _selectedCategoryId = category.id;
                        });
                      },
                      selectedColor: _parseColor(category.color),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 16),
                activitiesAsync.when(
                  data: (activities) {
                    if (activities.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 24.0),
                          child: Text('该分类下没有活动，点击右上角新建。'),
                        ),
                      );
                    }
                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: activities.length,
                      itemBuilder: (context, index) {
                        final activity = activities[index];
                        final category = categoryMap[activity.categoryId];
                        return ListTile(
                          title: Text(activity.name),
                          subtitle:
                              activity.defaultMinutes != null
                                  ? Text('默认时长 ${activity.defaultMinutes} 分钟')
                                  : null,
                          leading: CircleAvatar(
                            backgroundColor:
                                category != null
                                    ? _parseColor(category.color)
                                    : Colors.grey,
                            child: Text(
                              activity.name.characters.first,
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          onTap: () {
                            widget.onSelected(activity);
                            Navigator.of(context).pop();
                          },
                        );
                      },
                    );
                  },
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (err, stack) => Text('加载活动失败: $err'),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) => Text('加载分类失败: $err'),
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

  Future<void> _showCreateActivityDialog(
    List<Category> categories,
  ) async {
    final result = await showDialog<Activity>(
      context: context,
      builder: (context) => _NewActivityDialog(categories: categories),
    );
    if (result == null) return;
    if (!mounted) return;
    // 刷新当前分类活动列表。
    ref.invalidate(activitiesProvider);
    // 如果新建活动属于当前选中的分类，则通过 onSelected 回调关闭选择器并返回结果。
    if (result.categoryId == _selectedCategoryId) {
      widget.onSelected(result);
    }
  }
}

class _NewActivityDialog extends ConsumerStatefulWidget {
  final List<Category> categories;

  const _NewActivityDialog({required this.categories});

  @override
  ConsumerState<_NewActivityDialog> createState() => _NewActivityDialogState();
}

class _NewActivityDialogState extends ConsumerState<_NewActivityDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minutesController = TextEditingController();
  late int _categoryId;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _categoryId = widget.categories.first.id!;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新建活动'),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: '活动名称'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入活动名称';
                }
                return null;
              },
            ),
            DropdownButtonFormField<int>(
              initialValue: _categoryId,
              decoration: const InputDecoration(labelText: '分类'),
              items:
                  widget.categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _categoryId = value;
                  });
                }
              },
            ),
            TextFormField(
              controller: _minutesController,
              decoration: const InputDecoration(labelText: '默认时长（分钟，可选）'),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value != null && value.isNotEmpty) {
                  final minutes = int.tryParse(value);
                  if (minutes == null || minutes < 0) {
                    return '请输入有效数字';
                  }
                }
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child:
              _isLoading
                  ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                  : const Text('保存'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final name = _nameController.text.trim();
    final minutesText = _minutesController.text.trim();
    final defaultMinutes =
        minutesText.isEmpty ? null : int.tryParse(minutesText);
    final now = DateTime.now();

    final dao = ref.read(activityDaoProvider);
    final id = await dao.insert(
      Activity(
        name: name,
        categoryId: _categoryId,
        defaultMinutes: defaultMinutes,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final activity = Activity(
      id: id,
      name: name,
      categoryId: _categoryId,
      defaultMinutes: defaultMinutes,
      createdAt: now,
      updatedAt: now,
    );

    if (mounted) {
      Navigator.of(context).pop(activity);
    }
  }
}

/// 显示活动选择器底部弹窗。
Future<Activity?> showActivitySelector(BuildContext context) {
  return showModalBottomSheet<Activity>(
    context: context,
    isScrollControlled: true,
    builder: (context) => ActivitySelector(
      onSelected: (activity) => Navigator.of(context).pop(activity),
    ),
  );
}
