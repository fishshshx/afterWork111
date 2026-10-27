import 'package:path_provider/path_provider.dart';

import 'photo_file_service.dart';

/// 照片文件服务（生产环境入口）。
///
/// 使用 [path_provider] 获取应用私有目录，再委托给 [PhotoFileService]。
class PhotoService {
  static PhotoFileService? _instance;

  PhotoService._();

  /// 返回配置好应用私有目录的 [PhotoFileService]。
  static Future<PhotoFileService> getService() async {
    if (_instance != null) return _instance!;
    final appDir = await getApplicationDocumentsDirectory();
    _instance = PhotoFileService(baseDirectory: appDir);
    return _instance!;
  }
}
