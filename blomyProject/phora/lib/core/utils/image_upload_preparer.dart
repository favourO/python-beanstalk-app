import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class PreparedUploadImage {
  const PreparedUploadImage({
    required this.path,
    required this.bytes,
    required this.isTemporary,
  });

  final String path;
  final int bytes;
  final bool isTemporary;
}

class ImageUploadPreparer {
  static const int maxUploadBytes = 300 * 1024;
  static const int maxDimension = 1800;
  static const int minQuality = 72;
  static const int initialQuality = 92;

  Future<PreparedUploadImage> prepareForUpload(String sourcePath) async {
    final sourceFile = File(sourcePath);
    final originalBytes = await sourceFile.length();
    if (originalBytes <= maxUploadBytes) {
      return PreparedUploadImage(
        path: sourcePath,
        bytes: originalBytes,
        isTemporary: false,
      );
    }

    var quality = initialQuality;
    var preparedPath = _targetPath(sourcePath);
    XFile? compressed;

    while (quality >= minQuality) {
      compressed = await FlutterImageCompress.compressAndGetFile(
        sourcePath,
        preparedPath,
        format: CompressFormat.jpeg,
        quality: quality,
        minWidth: maxDimension,
        minHeight: maxDimension,
        keepExif: true,
      );

      if (compressed == null) {
        break;
      }

      final compressedBytes = await File(compressed.path).length();
      if (compressedBytes <= maxUploadBytes || quality == minQuality) {
        return PreparedUploadImage(
          path: compressed.path,
          bytes: compressedBytes,
          isTemporary: true,
        );
      }

      quality -= 6;
    }

    return PreparedUploadImage(
      path: sourcePath,
      bytes: originalBytes,
      isTemporary: false,
    );
  }

  String _targetPath(String sourcePath) {
    final dotIndex = sourcePath.lastIndexOf('.');
    final base = dotIndex > 0 ? sourcePath.substring(0, dotIndex) : sourcePath;
    return '${base}_lh_upload.jpg';
  }
}
