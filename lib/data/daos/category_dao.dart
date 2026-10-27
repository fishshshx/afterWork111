import '../../models/category.dart';
import '../app_database.dart';

class CategoryDao {
  final AppDatabase _db;

  CategoryDao(this._db);

  Future<int> insert(Category category) async {
    final db = await _db.database;
    return db.insert('categories', category.toMap());
  }

  Future<int> update(Category category) async {
    final db = await _db.database;
    return db.update(
      'categories',
      category.toMap(),
      where: 'id = ?',
      whereArgs: [category.id],
    );
  }

  /// 删除分类。如果该分类下仍有 activity，则抛出异常。
  Future<int> delete(int id) async {
    final db = await _db.database;

    final count = await db.rawQuery(
      'SELECT COUNT(*) as cnt FROM activities WHERE category_id = ?',
      [id],
    );
    final activityCount = (count.first['cnt'] as int?) ?? 0;
    if (activityCount > 0) {
      throw Exception('该分类下存在活动，无法删除');
    }

    return db.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> getAll() async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      orderBy: 'sort_order ASC, id ASC',
    );
    return maps.map((map) => Category.fromMap(map)).toList();
  }

  Future<Category?> getById(int id) async {
    final db = await _db.database;
    final maps = await db.query(
      'categories',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isEmpty) return null;
    return Category.fromMap(maps.first);
  }

  Future<void> updateSortOrder(List<Category> categories) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (var i = 0; i < categories.length; i++) {
        await txn.update(
          'categories',
          {'sort_order': i, 'updated_at': DateTime.now().toIso8601String()},
          where: 'id = ?',
          whereArgs: [categories[i].id],
        );
      }
    });
  }
}
