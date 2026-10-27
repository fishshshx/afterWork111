import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/plan.dart';
import '../providers/app_database_provider.dart';
import '../providers/plan_provider.dart';
import '../widgets/activity_selector.dart';

class PlanEditScreen extends ConsumerStatefulWidget {
  final int? planId;

  const PlanEditScreen({super.key, this.planId});

  @override
  ConsumerState<PlanEditScreen> createState() => _PlanEditScreenState();
}

class _PlanEditScreenState extends ConsumerState<PlanEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _estimatedMinutesController = TextEditingController();
  final _noteController = TextEditingController();

  Activity? _selectedActivity;
  DateTime _selectedDate = DateTime.now();
  TimeOfDay? _selectedTime;
  String? _planStatus;
  bool _isLoading = false;

  bool get isEditing => widget.planId != null;
  bool get _isCompletedPlan => _planStatus == 'completed';

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _loadPlan();
    }
  }

  Future<void> _loadPlan() async {
    final planWithActivity = await ref.read(planByIdProvider(widget.planId!).future);
    if (planWithActivity != null && mounted) {
      setState(() {
        _selectedActivity = planWithActivity.activity;
        _selectedDate = DateTime.parse(planWithActivity.plan.planDate);
        if (planWithActivity.plan.planTime != null) {
          final parts = planWithActivity.plan.planTime!.split(':');
          _selectedTime = TimeOfDay(
            hour: int.parse(parts[0]),
            minute: int.parse(parts[1]),
          );
        }
        _planStatus = planWithActivity.plan.status;
        _estimatedMinutesController.text =
            planWithActivity.plan.estimatedMinutes?.toString() ?? '';
        _noteController.text = planWithActivity.plan.note ?? '';
      });
    }
  }

  @override
  void dispose() {
    _estimatedMinutesController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? '编辑计划' : '新建计划'),
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isLoading || _isCompletedPlan ? null : _delete,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      _selectedActivity != null ? Colors.blue : Colors.grey,
                  child: Text(
                    _selectedActivity?.name.characters.first ?? '?',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Text(
                  _selectedActivity?.name ?? '选择活动',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: const Text('点击选择活动'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isCompletedPlan ? null : _pickActivity,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.calendar_today),
                title: Text(
                  DateFormat('yyyy-MM-dd EEEE', 'zh_CN').format(_selectedDate),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isCompletedPlan ? null : _pickDate,
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  _selectedTime != null
                      ? _selectedTime!.format(context)
                      : '可选：计划时间',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _isCompletedPlan ? null : _pickTime,
              ),
              TextFormField(
                controller: _estimatedMinutesController,
                decoration: const InputDecoration(
                  labelText: '预计时长（分钟，可选）',
                  prefixIcon: Icon(Icons.timer_outlined),
                ),
                keyboardType: TextInputType.number,
                enabled: !_isCompletedPlan,
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final minutes = int.tryParse(value);
                    if (minutes == null || minutes <= 0) {
                      return '请输入有效时长';
                    }
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  prefixIcon: Icon(Icons.notes),
                ),
                enabled: !_isCompletedPlan,
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              if (_isCompletedPlan)
                const Text(
                  '已完成计划不能直接编辑，请删除关联记录或删除计划。',
                  style: TextStyle(color: Colors.orange),
                )
              else
                ElevatedButton(
                  onPressed: _isLoading ? null : _save,
                  child:
                      _isLoading
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : Text(isEditing ? '保存修改' : '创建计划'),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickActivity() async {
    final activity = await showActivitySelector(context);
    if (activity != null) {
      setState(() {
        _selectedActivity = activity;
        if (_estimatedMinutesController.text.isEmpty &&
            activity.defaultMinutes != null) {
          _estimatedMinutesController.text =
              activity.defaultMinutes.toString();
        }
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedActivity == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('请选择活动')));
      return;
    }

    setState(() => _isLoading = true);

    final planDao = ref.read(planDaoProvider);
    final now = DateTime.now();
    final planTime =
        _selectedTime != null
            ? '${_selectedTime!.hour.toString().padLeft(2, '0')}:${_selectedTime!.minute.toString().padLeft(2, '0')}'
            : null;
    final estimatedText = _estimatedMinutesController.text.trim();
    final estimatedMinutes =
        estimatedText.isEmpty ? null : int.parse(estimatedText);

    if (isEditing) {
      final existing = await planDao.getById(widget.planId!);
      if (existing == null || existing.status != 'pending') {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('只能编辑待进行状态的计划')),
          );
        }
        setState(() => _isLoading = false);
        return;
      }

      await planDao.update(
        existing.copyWith(
          activityId: _selectedActivity!.id!,
          planDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
          planTime: planTime,
          estimatedMinutes: estimatedMinutes,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          updatedAt: now,
        ),
      );
    } else {
      await planDao.insert(
        Plan(
          activityId: _selectedActivity!.id!,
          planDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
          planTime: planTime,
          estimatedMinutes: estimatedMinutes,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
          status: 'pending',
          createdAt: now,
          updatedAt: now,
        ),
      );
    }

    ref.invalidate(plansProvider);
    ref.invalidate(plansByDateProvider);

    if (mounted) {
      context.pop();
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('删除计划'),
            content: const Text('确定要删除这个计划吗？关联记录会保留。'),
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

    setState(() => _isLoading = true);
    await ref.read(planDaoProvider).delete(widget.planId!);
    ref.invalidate(plansProvider);
    ref.invalidate(plansByDateProvider);

    if (mounted) {
      context.pop();
    }
  }
}
