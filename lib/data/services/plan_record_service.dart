import 'dart:convert';

import '../../models/plan.dart';
import '../app_database.dart';

/// 计划完成生成记录时的业务异常。
class PlanAlreadyCompletedException implements Exception {
  final String message;
  PlanAlreadyCompletedException([this.message = '该计划已生成记录']);

  @override
  String toString() => message;
}

class InvalidPlanStatusException implements Exception {
  final String message;
  InvalidPlanStatusException(this.message);

  @override
  String toString() => message;
}

class PlanRecordService {
  final AppDatabase _db;

  PlanRecordService(this._db);

  /// 将计划标记为完成，并在同一事务中生成一条关联记录。
  /// 若该计划已有记录，则抛出 [PlanAlreadyCompletedException]。
  /// 只有 pending 状态的计划可以被完成。
  Future<int> completePlan({
    required int planId,
    required int activityId,
    required String recordDate,
    required int actualMinutes,
    String? note,
    List<String>? photoPaths,
  }) async {
    final database = await _db.database;

    return database.transaction((txn) async {
      // 1. 读取计划
      final planRows = await txn.query(
        'plans',
        where: 'id = ?',
        whereArgs: [planId],
      );
      if (planRows.isEmpty) {
        throw InvalidPlanStatusException('计划不存在');
      }

      // 2. 检查是否已存在记录。必须在状态校验之前，确保“已生成记录”提示优先。
      final existingRecord = await txn.query(
        'records',
        where: 'plan_id = ?',
        whereArgs: [planId],
      );
      if (existingRecord.isNotEmpty) {
        throw PlanAlreadyCompletedException();
      }

      final plan = Plan.fromMap(planRows.first);
      if (plan.status != 'pending') {
        throw InvalidPlanStatusException(
          '只有待进行状态的计划可以标记完成',
        );
      }

      // 3. 插入记录
      final now = DateTime.now();
      await txn.insert('records', {
        'plan_id': planId,
        'activity_id': activityId,
        'record_date': recordDate,
        'actual_minutes': actualMinutes,
        'note': note,
        'photo_paths': jsonEncode(photoPaths ?? []),
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      });

      // 4. 更新计划状态
      final updated = await txn.update(
        'plans',
        {
          'status': 'completed',
          'updated_at': now.toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [planId],
      );

      return updated;
    });
  }

  /// 将 pending 计划标记为 skipped 或 cancelled。
  Future<int> markSkipped(int planId) async => _markStatus(planId, 'skipped');

  Future<int> markCancelled(int planId) async =>
      _markStatus(planId, 'cancelled');

  Future<int> _markStatus(int planId, String status) async {
    final database = await _db.database;

    return database.transaction((txn) async {
      final rows = await txn.query(
        'plans',
        where: 'id = ?',
        whereArgs: [planId],
      );
      if (rows.isEmpty) {
        throw InvalidPlanStatusException('计划不存在');
      }

      final plan = Plan.fromMap(rows.first);
      if (plan.status != 'pending') {
        throw InvalidPlanStatusException('只有待进行状态的计划可以更改为此状态');
      }

      return txn.update(
        'plans',
        {
          'status': status,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [planId],
      );
    });
  }
}
