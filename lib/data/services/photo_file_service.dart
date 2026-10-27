import 'dart:developer';
import 'dart:io';
import 'dart:math' hide log;

import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// 照片文件操作服务（不依赖 path_provider，便于测试注入目录）。
class PhotoFileService {
  static const String _photosDirName = 'photos';
  static const int _maxLongSide = 1920;
  static const int _jpegQuality = 85;

  final Directory baseDirectory;
  final Uuid _uuid = const Uuid();

  PhotoFileService({required this.baseDirectory});

  /// 返回照片目录（baseDirectory/photos）。
  Future<Directory> getPhotosDirectory() async {
    final photosDir = Directory(p.join(baseDirectory.path, _photosDirName));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }
    return photosDir;
  }

  /// 将 [sourceFile] 复制/压缩到照片目录，返回相对路径（相对于 photos/）。
  Future<String> copyAndCompressPhoto(File sourceFile) async {
    final photosDir = await getPhotosDirectory();
    final ext = p.extension(sourceFile.path).toLowerCase();
    final targetName = '${_uuid.v4()}${ext.isEmpty ? '.jpg' : ext}';
    final targetFile = File(p.join(photosDir.path, targetName));

    final bytes = await sourceFile.readAsBytes();
    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      await sourceFile.copy(targetFile.path);
      return targetName;
    }

    final (targetWidth, targetHeight) = _calculateTargetSize(
      decoded.width,
      decoded.height,
      _maxLongSide,
    );

    final resized =
        (targetWidth == decoded.width && targetHeight == decoded.height)
            ? decoded
            : img.copyResize(
                decoded,
                width: targetWidth,
                height: targetHeight,
              );

    final encoded = img.encodeJpg(resized, quality: _jpegQuality);
    await targetFile.writeAsBytes(encoded);
    return targetName;
  }

  /// 批量复制/压缩照片。
  Future<List<String>> copyAndCompressPhotos(List<File> sourceFiles) async {
    final results = <String>[];
    for (final file in sourceFiles) {
      results.add(await copyAndCompressPhoto(file));
    }
    return results;
  }

  /// 根据相对路径删除照片文件。删除失败只记录日志，不抛异常。
  Future<void> deletePhoto(String relativePath) async {
    try {
      final photosDir = await getPhotosDirectory();
      final file = File(p.join(photosDir.path, relativePath));
      if (await file.exists()) {
        await file.delete();
      }
    } catch (e, stack) {
      log('删除照片失败: $relativePath', error: e, stackTrace: stack);
    }
  }

  /// 批量删除照片文件。
  Future<void> deletePhotos(List<String> relativePaths) async {
    for (final path in relativePaths) {
      await deletePhoto(path);
    }
  }

  /// 根据相对路径返回绝对路径的 [File]。
  Future<File> absoluteFile(String relativePath) async {
    final photosDir = await getPhotosDirectory();
    return File(p.join(photosDir.path, relativePath));
  }

  (int, int) _calculateTargetSize(int width, int height, int maxSide) {
    if (width <= maxSide && height <= maxSide) {
      return (width, height);
    }
    if (width >= height) {
      return (maxSide, max((height * maxSide / width).round(), 1));
    } else {
      return (max((width * maxSide / height).round(), 1), maxSide);
    }
  }
}
