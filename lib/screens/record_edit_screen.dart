import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/record.dart';
import '../models/record_with_activity.dart';
import '../providers/app_database_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/activity_selector.dart';
import '../widgets/photo_grid.dart';

/// 记录补录 / 编辑页。
///
/// - [recordId] 为 null 时表示新建记录（直接补录）。
/// - 编辑模式下 activity 与日期只读，只允许修改实际时长、感想、照片。
class RecordEditScreen extends ConsumerStatefulWidget {
  final int? recordId;

  const RecordEditScreen({super.key, this.recordId});

  @override
  ConsumerState<RecordEditScreen> createState() => _RecordEditScreenState();
}

class _RecordEditScreenState extends ConsumerState<RecordEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();

  Activity? _selectedActivity;
  DateTime _selectedDate = DateTime.now();
  final List<String> _photoPaths = [];
  final List<String> _removedPhotoPaths = [];
  bool _initialized = false;
  bool _isLoading = false;

  bool get isEditing => widget.recordId != null;

  @override
  void dispose() {
    _minutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final body =
        isEditing
            ? ref.watch(recordByIdProvider(widget.recordId!)).when(
              data: (data) {
                if (data == null) {
                  return const Center(child: Text('记录不存在'));
                }
                if (!_initialized) {
                  _selectedActivity = data.activity;
                  _selectedDate = DateTime.parse(data.record.recordDate);
                  _minutesController.text =
                      data.record.actualMinutes.toString();
                  if (data.record.note != null) {
                    _noteController.text = data.record.note!;
                  }
                  _photoPaths.addAll(data.record.photoPaths);
                  _initialized = true;
                }
                return _buildForm(context, data);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error:
                  (err, stack) => Center(child: Text('加载失败: $err')),
            )
            : _buildForm(context, null);

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑记录' : '补录记录')),
      body: body,
    );
  }

  Widget _buildForm(BuildContext context, RecordWithActivity? existing) {
    final theme = Theme.of(context);
    final photoService = ref.watch(photoFileServiceProvider);

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: ListView(
          children: [
            _buildActivityField(theme),
            const SizedBox(height: 16),
            _buildDateField(theme),
            const SizedBox(height: 16),
            TextFormField(
              controller: _minutesController,
              decoration: const InputDecoration(
                labelText: '实际时长（分钟）',
                prefixIcon: Icon(Icons.timer_outlined),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return '请输入实际时长';
                }
                final minutes = int.tryParse(value.trim());
                if (minutes == null || minutes <= 0) {
                  return '请输入有效的正整数分钟';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: '感想（可选）',
                prefixIcon: Icon(Icons.notes),
              ),
              maxLines: 4,
            ),
            const SizedBox(height: 24),
            Text(
              '照片（${_photoPaths.length}/9）',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            PhotoGrid(
              photoPaths: _photoPaths,
              photoService: photoService,
              onAdd: _addPhotos,
              onRemove: _removePhoto,
              onPreview: _previewPhoto,
              readOnly: false,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isLoading ? null : () => _save(existing),
              child:
                  _isLoading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : Text(isEditing ? '保存修改' : '保存记录'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _isLoading ? null : () => context.pop(),
              child: const Text('取消'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityField(ThemeData theme) {
    final activity = _selectedActivity;

    return InkWell(
      onTap: isEditing ? null : _pickActivity,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '活动',
          prefixIcon: const Icon(Icons.category_outlined),
          enabled: !isEditing,
        ),
        child: activity == null
            ? Text(
              '点击选择活动',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.hintColor,
              ),
            )
            : Text(activity.name),
      ),
    );
  }

  Widget _buildDateField(ThemeData theme) {
    return InkWell(
      onTap: isEditing ? null : _pickDate,
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: '日期',
          prefixIcon: const Icon(Icons.calendar_today_outlined),
          enabled: !isEditing,
        ),
        child: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
      ),
    );
  }

  Future<void> _pickActivity() async {
    final activity = await showActivitySelector(context);
    if (activity != null) {
      setState(() {
        _selectedActivity = activity;
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _addPhotos() async {
    if (_photoPaths.length >= 9) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('最多添加 9 张照片')),
      );
      return;
    }

    final source = await showPhotoSourceSheet(context);
    if (source == null) return;

    final picker = ImagePicker();
    final photoService = ref.read(photoFileServiceProvider);

    try {
      if (source == ImageSource.camera) {
        final picked = await picker.pickImage(source: ImageSource.camera);
        if (picked == null) return;
        final relativePath = await photoService.copyAndCompressPhoto(
          File(picked.path),
        );
        setState(() {
          _photoPaths.add(relativePath);
        });
      } else {
        final remaining = 9 - _photoPaths.length;
        final picked = await picker.pickMultiImage(limit: remaining);
        for (final xfile in picked) {
          final relativePath = await photoService.copyAndCompressPhoto(
            File(xfile.path),
          );
          _photoPaths.add(relativePath);
        }
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('添加照片失败: $e')),
        );
      }
    }
  }

  Future<void> _removePhoto(int index) async {
    final removed = _photoPaths.removeAt(index);
    _removedPhotoPaths.add(removed);
    setState(() {});
  }

  Future<void> _previewPhoto(int index) async {
    final photoService = ref.read(photoFileServiceProvider);
    await showDialog(
      context: context,
      builder: (context) => PhotoPreview(
        photoPaths: _photoPaths,
        photoService: photoService,
        initialIndex: index,
      ),
    );
  }

  Future<void> _save(RecordWithActivity? existing) async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('请选择活动')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final minutes = int.parse(_minutesController.text.trim());
    final note =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
    final date = DateFormat('yyyy-MM-dd').format(_selectedDate);

    try {
      final dao = ref.read(recordDaoProvider);
      final now = DateTime.now();

      if (existing == null) {
        await dao.insert(
          Record(
            activityId: _selectedActivity!.id!,
            recordDate: date,
            actualMinutes: minutes,
            note: note,
            photoPaths: List.from(_photoPaths),
            createdAt: now,
            updatedAt: now,
          ),
        );
      } else {
        await dao.update(
          existing.record.copyWith(
            actualMinutes: minutes,
            note: note,
            photoPaths: List.from(_photoPaths),
            updatedAt: now,
          ),
        );
      }

      ref.invalidate(recordsProvider);
      ref.invalidate(recordsByDateProvider);
      ref.invalidate(plansProvider);
      ref.invalidate(plansByDateProvider);

      // 保存成功后再删除被移除的照片文件。
      final photoService = ref.read(photoFileServiceProvider);
      for (final path in _removedPhotoPaths) {
        await photoService.deletePhoto(path);
      }
      _removedPhotoPaths.clear();

      if (mounted) {
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
