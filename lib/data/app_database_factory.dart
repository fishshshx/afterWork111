import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;

import 'app_database.dart';

/// 初始化生产环境数据库。需要在 runApp 之前调用。
Future<void> initAppDatabase() async {
  AppDatabase.setFactory(sqflite.databaseFactory);
  final Directory documentsDir = await getApplicationDocumentsDirectory();
  AppDatabase.setDefaultPath(join(documentsDir.path, 'after_work.db'));
}
