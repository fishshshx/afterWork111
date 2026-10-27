// ignore_for_file: no_leading_underscores_for_local_identifiers

import 'dart:io';

import 'package:after_work/data/services/photo_file_service.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  group('PhotoFileService', () {
    late Directory tempDir;
    late PhotoFileService photoService;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('after_work_photo_test_');
      photoService = PhotoFileService(baseDirectory: tempDir);
    });

    tearDown(() async {
      try {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      } on FileSystemException {
        // Windows 上偶发文件句柄未释放导致删除失败，忽略即可，不影响断言。
      }
    });

    Future<File> createTestImage(String name, {int width = 3000, int height = 2000}) async {
      final image = img.Image(width: width, height: height);
      final bytes = img.encodeJpg(image, quality: 90);
      final file = File(p.join(tempDir.path, name));
      await file.writeAsBytes(bytes);
      return file;
    }

    test('copyAndCompressPhoto creates file in photos directory', () async {
      final source = await createTestImage('source.jpg');

      final relativePath = await photoService.copyAndCompressPhoto(source);

      final photosDir = await photoService.getPhotosDirectory();
      final savedFile = File(p.join(photosDir.path, relativePath));
      expect(await savedFile.exists(), isTrue);
    });

    test('copyAndCompressPhoto resizes image when long side exceeds 1920', () async {
      final source = await createTestImage('large.jpg', width: 3000, height: 2000);

      final relativePath = await photoService.copyAndCompressPhoto(source);

      final photosDir = await photoService.getPhotosDirectory();
      final savedFile = File(p.join(photosDir.path, relativePath));
      final decoded = img.decodeImage(await savedFile.readAsBytes());
      expect(decoded, isNotNull);
      expect(decoded!.width <= 1920 && decoded.height <= 1920, isTrue);
      expect(decoded.width, 1920);
    });

    test('deletePhoto removes the file', () async {
      final source = await createTestImage('to_delete.jpg', width: 100, height: 100);
      final relativePath = await photoService.copyAndCompressPhoto(source);

      final photosDir = await photoService.getPhotosDirectory();
      final savedFile = File(p.join(photosDir.path, relativePath));
      expect(await savedFile.exists(), isTrue);

      await photoService.deletePhoto(relativePath);

      expect(await savedFile.exists(), isFalse);
    });

    test('deletePhoto does not throw for non-existent file', () async {
      expect(
        () async => await photoService.deletePhoto('non_existent.jpg'),
        returnsNormally,
      );
    });
  });
}
