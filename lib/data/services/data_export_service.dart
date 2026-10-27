import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../app_database.dart';
import 'photo_file_service.dart';

/// 导出数据时写入 zip 内的 JSON 文件名。
const String kExportManifestName = 'data.json';

/// 导出数据的格式版本号，用于兼容校验。
const int kExportFormatVersion = 1;

/// 导入数据时抛出的校验异常。
class InvalidBackupException implements Exception {
  final String message;
  InvalidBackupException(this.message);

  @override
  String toString() => message;
}

/// 数据导出 / 导入服务。
///
/// 导出：将 categories / activities / plans / records / check_in_items /
/// check_in_records 六张表的数据序列化为 JSON，并连同照片文件一起打包为 zip。
/// 导入：解压 zip、校验 manifest、先备份现有数据，再在事务中覆盖导入。
class DataExportService {
  final AppDatabase _db;
  final PhotoFileService _photoFileService;

  DataExportService(this._db, this._photoFileService);

  /// 将全部数据导出为 JSON 字符串。
  Future<String> exportToJson() async {
    final db = await _db.database;

    final categories = await db.query('categories', orderBy: 'id');
    final activities = await db.query('activities', orderBy: 'id');
    final plans = await db.query('plans', orderBy: 'id');
    final records = await db.query('records', orderBy: 'id');
    final checkInItems = await db.query('check_in_items', orderBy: 'id');
    final checkInRecords =
        await db.query('check_in_records', orderBy: 'id');

    final manifest = {
      'format_version': kExportFormatVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'categories': categories,
      'activities': activities,
      'plans': plans,
      'records': records,
      'check_in_items': checkInItems,
      'check_in_records': checkInRecords,
    };

    return jsonEncode(manifest);
  }

  /// 将全部数据（含照片）导出为 zip 文件，写入 [outputPath]。
  ///
  /// 返回实际写入的字节数。照片不存在时跳过。
  Future<int> exportToZip(String outputPath) async {
    final jsonStr = await exportToJson();

    final archive = Archive();
    archive.addFile(
      ArchiveFile(kExportManifestName, utf8.encode(jsonStr).length,
          utf8.encode(jsonStr)),
    );

    // 打包照片文件（位于 baseDirectory/photos/ 目录下）。
    final photosDir = await _photoFileService.getPhotosDirectory();
    if (await photosDir.exists()) {
      await for (final entity in photosDir.list(recursive: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        final bytes = await entity.readAsBytes();
        archive.addFile(
          ArchiveFile('photos/$name', bytes.length, bytes),
        );
      }
    }

    final zipEncoder = ZipEncoder();
    final zipBytes = zipEncoder.encode(archive);
    final outFile = File(outputPath);
    await outFile.writeAsBytes(zipBytes);
    return zipBytes.length;
  }

  /// 从 JSON 字符串导入数据，覆盖当前数据库。
  ///
  /// 返回导入的记录数量统计。
  Future<ImportResult> importFromJson(String jsonStr) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map<String, dynamic>) {
      throw InvalidBackupException('备份文件格式错误：不是有效的 JSON 对象');
    }

    final manifest = decoded;
    final version = manifest['format_version'];
    if (version is! int || version != kExportFormatVersion) {
      throw InvalidBackupException('备份文件版本不支持：$version');
    }

    // 校验必需字段。
    final requiredKeys = [
      'categories',
      'activities',
      'plans',
      'records',
      'check_in_items',
      'check_in_records',
    ];
    for (final key in requiredKeys) {
      if (manifest[key] is! List) {
        throw InvalidBackupException('备份文件缺少字段：$key');
      }
    }

    final db = await _db.database;
    return db.transaction((txn) async {
      // 1. 清空现有数据（按依赖顺序：先子表后父表）。
      await txn.delete('check_in_records');
      await txn.delete('check_in_items');
      await txn.delete('records');
      await txn.delete('plans');
      await txn.delete('activities');
      await txn.delete('categories');

      // 2. 按依赖顺序重新插入（先父表后子表）。
      final counts = <String, int>{};

      counts['categories'] = await _insertRows(
          txn, 'categories', manifest['categories'] as List);
      counts['activities'] = await _insertRows(
          txn, 'activities', manifest['activities'] as List);
      counts['plans'] =
          await _insertRows(txn, 'plans', manifest['plans'] as List);
      counts['records'] =
          await _insertRows(txn, 'records', manifest['records'] as List);
      counts['check_in_items'] = await _insertRows(
          txn, 'check_in_items', manifest['check_in_items'] as List);
      counts['check_in_records'] = await _insertRows(
          txn, 'check_in_records', manifest['check_in_records'] as List);

      return ImportResult(counts);
    });
  }

  /// 从 zip 文件导入数据。
  ///
  /// 先校验 zip 结构，再调用 [importFromJson]。照片文件会一并恢复。
  Future<ImportResult> importFromZip(String zipPath) async {
    final zipFile = File(zipPath);
    if (!await zipFile.exists()) {
      throw InvalidBackupException('备份文件不存在：$zipPath');
    }
    final bytes = await zipFile.readAsBytes();

    final archive = ZipDecoder().decodeBytes(bytes);
    ArchiveFile? manifestFile;
    final photoFiles = <ArchiveFile>[];

    for (final file in archive) {
      if (file.name == kExportManifestName) {
        manifestFile = file;
      } else if (file.name.startsWith('photos/')) {
        photoFiles.add(file);
      }
    }

    if (manifestFile == null) {
      throw InvalidBackupException('备份文件缺少 $kExportManifestName');
    }

    final jsonStr = utf8.decode(manifestFile.content as List<int>);
    final result = await importFromJson(jsonStr);

    // 恢复照片文件。
    if (photoFiles.isNotEmpty) {
      final photosDir = await _photoFileService.getPhotosDirectory();
      for (final file in photoFiles) {
        final name = p.basename(file.name);
        final target = File(p.join(photosDir.path, name));
        await target.writeAsBytes(file.content as List<int>);
      }
    }

    return result;
  }

  Future<int> _insertRows(
    dynamic txn,
    String table,
    List rows,
  ) async {
    var count = 0;
    for (final row in rows) {
      if (row is! Map) continue;
      await txn.insert(table, Map<String, dynamic>.from(row));
      count++;
    }
    return count;
  }
}

/// 导入结果统计。
class ImportResult {
  final Map<String, int> counts;

  ImportResult(this.counts);

  int get total => counts.values.fold(0, (sum, c) => sum + c);

  int get categories => counts['categories'] ?? 0;
  int get activities => counts['activities'] ?? 0;
  int get plans => counts['plans'] ?? 0;
  int get records => counts['records'] ?? 0;
  int get checkInItems => counts['check_in_items'] ?? 0;
  int get checkInRecords => counts['check_in_records'] ?? 0;

  @override
  String toString() =>
      '分类 $categories，活动 $activities，计划 $plans，记录 $records，'
      '打卡项 $checkInItems，打卡记录 $checkInRecords';
}
