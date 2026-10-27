import 'package:sqflite_common/sqlite_api.dart';

/// 数据库版本号，从 1 开始。
const int _schemaVersion = 1;

class AppDatabase {
  static final AppDatabase _instance = AppDatabase._internal();
  static Database? _database;
  static String? _defaultPath;
  static DatabaseFactory? _factory;

  final String? testDbPath;
  final DatabaseFactory? testFactory;

  AppDatabase._internal({this.testDbPath, this.testFactory});

  /// 设置数据库工厂。生产环境使用 `package:sqflite` 的 [databaseFactory]。
  static void setFactory(DatabaseFactory factory) {
    _factory = factory;
  }

  /// 设置生产环境默认数据库路径。必须在首次调用 [AppDatabase] 之前完成。
  static void setDefaultPath(String path) {
    _defaultPath = path;
  }

  factory AppDatabase() {
    if (_factory == null) {
      throw StateError(
        'AppDatabase factory not set. Call AppDatabase.setFactory(factory) before using the singleton.',
      );
    }
    if (_defaultPath == null) {
      throw StateError(
        'AppDatabase default path not set. Call AppDatabase.setDefaultPath(path) before using the singleton.',
      );
    }
    return _instance;
  }

  /// 用于单元测试，返回一个独立的实例，避免与单例冲突。
  factory AppDatabase.test(String dbPath, DatabaseFactory factory) =>
      AppDatabase._internal(testDbPath: dbPath, testFactory: factory);

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// 关闭当前打开的数据库连接。主要用于测试清理。
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }

  Future<Database> _initDatabase() async {
    final factory = testFactory ?? _factory!;
    final path = testDbPath ?? _defaultPath!;

    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: _schemaVersion,
        onCreate: _onCreate,
        onUpgrade: _onUpgrade,
        onOpen: _onOpen,
      ),
    );
  }

  Future<void> _onOpen(Database db) async {
    // 启用外键约束
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE,
        color TEXT NOT NULL,
        sort_order INTEGER DEFAULT 0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE activities (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        category_id INTEGER NOT NULL,
        default_minutes INTEGER,
        archived_at TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE plans (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        activity_id INTEGER NOT NULL,
        plan_date TEXT NOT NULL,
        plan_time TEXT,
        estimated_minutes INTEGER,
        note TEXT,
        status TEXT NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE RESTRICT
      )
    ''');

    await db.execute('''
      CREATE TABLE records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        plan_id INTEGER,
        activity_id INTEGER NOT NULL,
        record_date TEXT NOT NULL,
        actual_minutes INTEGER NOT NULL,
        note TEXT,
        photo_paths TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE SET NULL,
        FOREIGN KEY (activity_id) REFERENCES activities(id) ON DELETE RESTRICT,
        UNIQUE(plan_id)
      )
    ''');

    await db.execute('''
      CREATE TABLE check_in_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        frequency TEXT NOT NULL DEFAULT 'daily',
        start_date TEXT NOT NULL,
        archived_at TEXT,
        is_enabled INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE check_in_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id INTEGER,
        date TEXT NOT NULL,
        is_completed INTEGER NOT NULL DEFAULT 1,
        note TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES check_in_items(id) ON DELETE SET NULL,
        UNIQUE(item_id, date)
      )
    ''');

    await _seedCategories(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // 按版本逐步迁移
    if (oldVersion < 2) {
      // v2 迁移占位
    }
  }

  Future<void> _seedCategories(Database db) async {
    final now = DateTime.now().toIso8601String();
    final preset = [
      {'name': '运动', 'color': '#FF5252', 'sort_order': 0},
      {'name': '学习', 'color': '#448AFF', 'sort_order': 1},
      {'name': '娱乐', 'color': '#FFAB40', 'sort_order': 2},
      {'name': '创作', 'color': '#69F0AE', 'sort_order': 3},
      {'name': '社交', 'color': '#E040FB', 'sort_order': 4},
      {'name': '其他', 'color': '#BDBDBD', 'sort_order': 5},
    ];

    for (final item in preset) {
      await db.insert('categories', {
        'name': item['name'],
        'color': item['color'],
        'sort_order': item['sort_order'],
        'created_at': now,
        'updated_at': now,
      });
    }
  }
}
