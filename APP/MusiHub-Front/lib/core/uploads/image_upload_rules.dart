import 'dart:io';

import 'package:http_parser/http_parser.dart';

abstract final class ImageUploadRules {
  static const maxSizeBytes = 5 * 1024 * 1024;

  static MediaType? contentTypeForPath(String path) {
    final normalizedPath = path.toLowerCase();

    if (normalizedPath.endsWith('.jpg') || normalizedPath.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }

    if (normalizedPath.endsWith('.png')) {
      return MediaType('image', 'png');
    }

    if (normalizedPath.endsWith('.webp')) {
      return MediaType('image', 'webp');
    }

    return null;
  }

  static Future<bool> isTooLarge(File file) async {
    final length = await file.length();
    return length > maxSizeBytes;
  }
}
