import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/check_in_item.dart';
import '../providers/app_database_provider.dart';
import '../providers/check_in_provider.dart';

/// 打卡项编辑/新建页。
///
/// [itemId] 为 null 时新建，否则编辑。
class CheckInItemEditScreen extends ConsumerStatefulWidget {
  final int? itemId;

  const CheckInItemEditScreen({super.key, this.itemId});

  @override
  ConsumerState<CheckInItemEditScreen> createState() =>
      _CheckInItemEditScreenState();
}

class _CheckInItemEditScreenState extends ConsumerState<CheckInItemEditScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime _startDate = DateTime.now();
  bool _isLoading = false;

  bool get isEditing => widget.itemId != null;

  @override
  void initState() {
    super.initState();
    if (isEditing) {
      _load();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final dao = ref.read(checkInItemDaoProvider);
    final item = await dao.getById(widget.itemId!);
    if (item == null || !mounted) return;
    setState(() {
      _nameController.text = item.name;
      _startDate = DateTime.parse(item.startDate);
    });
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _startDate = picked);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final dao = ref.read(checkInItemDaoProvider);
    final now = DateTime.now();
    final startDate = DateFormat('yyyy-MM-dd').format(_startDate);

    try {
      if (isEditing) {
        final item = await dao.getById(widget.itemId!);
        if (item == null) {
          throw Exception('打卡项不存在');
        }
        await dao.update(
          item.copyWith(
            name: _nameController.text.trim(),
            startDate: startDate,
            updatedAt: now,
          ),
        );
      } else {
        await dao.insert(
          CheckInItem(
            name: _nameController.text.trim(),
            startDate: startDate,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
      ref.invalidate(checkInItemsProvider);
      ref.invalidate(activeCheckInItemsProvider);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? '编辑打卡项' : '新建打卡项')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: '名称',
                hintText: '如：早睡、早起',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return '请输入名称';
                return null;
              },
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('开始日期'),
              subtitle: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickStartDate,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _isLoading ? null : _save,
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(isEditing ? '保存' : '创建'),
            ),
          ],
        ),
      ),
    );
  }
}
