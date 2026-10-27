import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../data/services/plan_record_service.dart';
import '../models/plan_with_activity.dart';
import '../providers/app_database_provider.dart';
import '../providers/plan_provider.dart';
import '../providers/record_provider.dart';
import '../widgets/photo_grid.dart';

class RecordFromPlanScreen extends ConsumerStatefulWidget {
  final int planId;

  const RecordFromPlanScreen({super.key, required this.planId});

  @override
  ConsumerState<RecordFromPlanScreen> createState() =>
      _RecordFromPlanScreenState();
}

class _RecordFromPlanScreenState extends ConsumerState<RecordFromPlanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _minutesController = TextEditingController();
  final _noteController = TextEditingController();
  final List<String> _photoPaths = [];
  final List<String> _removedPhotoPaths = [];
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(planByIdProvider(widget.planId));

    return Scaffold(
      appBar: AppBar(title: const Text('完成计划')),
      body: planAsync.when(
        data: (data) {
          if (data == null) {
            return const Center(child: Text('计划不存在'));
          }

          if (_minutesController.text.isEmpty) {
            final prefill =
                data.plan.estimatedMinutes ??
                data.activity.defaultMinutes ??
                30;
            _minutesController.text = prefill.toString();
          }

          final photoService = ref.watch(photoFileServiceProvider);

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.blue,
                        child: Text(
                          data.activity.name.characters.first,
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(data.activity.name),
                      subtitle: Text(
                        '${data.category.name} · ${data.plan.planDate}${data.plan.planTime != null ? ' ${data.plan.planTime}' : ''}',
                      ),
                    ),
                  ),
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
                        return '请输入有效时长';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
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
                    style: Theme.of(context).textTheme.titleMedium,
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
                    onPressed: _isLoading ? null : () => _save(data),
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('生成记录'),
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
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('加载失败: $err')),
      ),
    );
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

  Future<void> _save(PlanWithActivity data) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final minutes = int.parse(_minutesController.text.trim());
    final note =
        _noteController.text.trim().isEmpty ? null : _noteController.text.trim();

    try {
      await ref.read(planRecordServiceProvider).completePlan(
        planId: widget.planId,
        activityId: data.plan.activityId,
        recordDate: data.plan.planDate,
        actualMinutes: minutes,
        note: note,
        photoPaths: _photoPaths,
      );

      ref.invalidate(plansProvider);
      ref.invalidate(plansByDateProvider);
      ref.invalidate(recordsProvider);
      ref.invalidate(recordsByDateProvider);

      final photoService = ref.read(photoFileServiceProvider);
      for (final path in _removedPhotoPaths) {
        await photoService.deletePhoto(path);
      }
      _removedPhotoPaths.clear();

      if (mounted) {
        context.pop();
      }
    } on PlanAlreadyCompletedException catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('该计划已生成记录')),
        );
      }
    } on InvalidPlanStatusException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
}
