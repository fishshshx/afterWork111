import '../../models/plan.dart';
import '../../models/plan_with_activity.dart';
import '../app_database.dart';

class PlanDao {
  final AppDatabase _db;

  PlanDao(this._db);

  Future<int> insert(Plan plan) async {
    final db = await _db.database;
    return db.insert('plans', plan.toMap());
  }

  Future<int> update(Plan plan) async {
    final db = await _db.database;
    return db.update(
      'plans',
      plan.toMap(),
      where: 'id = ?',
      whereArgs: [plan.id],
    );
  }

  Future<int> delete(int id) async {
    final db = await _db.database;
    return db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<Plan?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'plans',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Plan.fromMap(maps.first);
  }

  Future<List<PlanWithActivity>> getAll() async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT plans.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM plans
      JOIN activities ON plans.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      ORDER BY plans.plan_date DESC, plans.plan_time DESC NULLS LAST
    ''');
    return maps.map((map) => PlanWithActivity.fromMap(map)).toList();
  }

  Future<List<PlanWithActivity>> getByDate(String date) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT plans.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM plans
      JOIN activities ON plans.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      WHERE plans.plan_date = ?
      ORDER BY plans.plan_time DESC NULLS LAST
    ''', [date]);
    return maps.map((map) => PlanWithActivity.fromMap(map)).toList();
  }

  Future<List<PlanWithActivity>> getByDateRange(String startDate,
      String endDate) async {
    final db = await _db.database;
    final maps = await db.rawQuery('''
      SELECT plans.*,
             activities.name AS activity_name,
             activities.default_minutes AS activity_default_minutes,
             activities.created_at AS activity_created_at,
             activities.updated_at AS activity_updated_at,
             categories.id AS category_id,
             categories.name AS category_name,
             categories.color AS category_color,
             categories.sort_order AS category_sort_order,
             categories.created_at AS category_created_at,
             categories.updated_at AS category_updated_at
      FROM plans
      JOIN activities ON plans.activity_id = activities.id
      JOIN categories ON activities.category_id = categories.id
      WHERE plans.plan_date >= ? AND plans.plan_date <= ?
      ORDER BY plans.plan_date DESC, plans.plan_time DESC NULLS LAST
    ''', [startDate, endDate]);
    return maps.map((map) => PlanWithActivity.fromMap(map)).toList();
  }

  Future<void> updateStatus(int id, String status) async {
    final db = await _db.database;
    await db.update(
      'plans',
      {
        'status': status,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
