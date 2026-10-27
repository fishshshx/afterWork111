import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/services/photo_file_service.dart';

/// 照片网格组件。
///
/// 显示一组相对路径照片，支持预览、删除、添加。
class PhotoGrid extends StatelessWidget {
  final List<String> photoPaths;
  final PhotoFileService photoService;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPreview;
  final bool readOnly;

  const PhotoGrid({
    super.key,
    required this.photoPaths,
    required this.photoService,
    required this.onAdd,
    required this.onRemove,
    required this.onPreview,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...photoPaths.asMap().entries.map((entry) {
          final index = entry.key;
          final path = entry.value;
          return _PhotoThumbnail(
            relativePath: path,
            photoService: photoService,
            onTap: () => onPreview(index),
            onRemove: readOnly ? null : () => onRemove(index),
          );
        }),
        if (!readOnly && photoPaths.length < 9)
          InkWell(
            onTap: onAdd,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.add_a_photo_outlined),
            ),
          ),
      ],
    );
  }
}

class _PhotoThumbnail extends StatelessWidget {
  final String relativePath;
  final PhotoFileService photoService;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _PhotoThumbnail({
    required this.relativePath,
    required this.photoService,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<File>(
      future: photoService.absoluteFile(relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        return Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: file != null && file.existsSync()
                    ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.cover),
                    )
                    : const Center(child: Icon(Icons.image)),
              ),
            ),
            if (onRemove != null)
              Positioned(
                top: 0,
                right: 0,
                child: InkWell(
                  onTap: onRemove,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 全屏照片预览。
class PhotoPreview extends StatelessWidget {
  final List<String> photoPaths;
  final PhotoFileService photoService;
  final int initialIndex;

  const PhotoPreview({
    super.key,
    required this.photoPaths,
    required this.photoService,
    required this.initialIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog.fullscreen(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: PageView.builder(
          controller: PageController(initialPage: initialIndex),
          itemCount: photoPaths.length,
          itemBuilder: (context, index) {
            return FutureBuilder<File>(
              future: photoService.absoluteFile(photoPaths[index]),
              builder: (context, snapshot) {
                final file = snapshot.data;
                if (file == null || !file.existsSync()) {
                  return const Center(
                    child: Icon(Icons.broken_image, color: Colors.white),
                  );
                }
                return InteractiveViewer(
                  child: Center(child: Image.file(file)),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// 显示照片来源选择底部菜单，返回用户选择的 [ImageSource] 或 null。
Future<ImageSource?> showPhotoSourceSheet(BuildContext context) {
  return showModalBottomSheet<ImageSource>(
    context: context,
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: const Text('从相册选择'),
            onTap: () => Navigator.of(context).pop(ImageSource.gallery),
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: const Text('拍照'),
            onTap: () => Navigator.of(context).pop(ImageSource.camera),
          ),
        ],
      ),
    ),
  );
}
