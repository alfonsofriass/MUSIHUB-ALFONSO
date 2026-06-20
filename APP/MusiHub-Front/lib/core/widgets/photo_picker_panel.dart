import 'dart:io';

import 'package:flutter/material.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';

class PhotoPickerPanel extends StatelessWidget {
  const PhotoPickerPanel({
    super.key,
    this.photoUrl,
    this.localPhotoPath,
    required this.onTap,
    this.isUploading = false,
    this.radius = 40,
    this.placeholderIcon = Icons.photo_camera_outlined,
    this.buttonLabel = 'Elegir foto',
    this.uploadingLabel = 'Subiendo...',
  });

  final String? photoUrl;
  final String? localPhotoPath;
  final VoidCallback? onTap;
  final bool isUploading;
  final double radius;
  final IconData placeholderIcon;
  final String buttonLabel;
  final String uploadingLabel;

  @override
  Widget build(BuildContext context) {
    final localPath = localPhotoPath?.trim();
    final resolvedPhotoUrl = ApiConfig.publicFileUrl(photoUrl);
    final imageProvider = _imageProvider(localPath, resolvedPhotoUrl);
    final size = radius * 2;

    return Center(
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircleAvatar(
                radius: radius,
                backgroundColor: MusiHubColors.fieldGrey,
                backgroundImage: imageProvider,
                child: imageProvider == null
                    ? Icon(placeholderIcon, size: radius * 0.82)
                    : null,
              ),
              if (isUploading)
                Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.28),
                    shape: BoxShape.circle,
                  ),
                  child: const Center(
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onTap,
            icon: const Icon(Icons.photo_library_outlined),
            label: Text(isUploading ? uploadingLabel : buttonLabel),
          ),
          const SizedBox(height: 6),
          Text(
            'JPG, PNG o WebP. Máximo 5 MB.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  ImageProvider? _imageProvider(String? localPath, String resolvedPhotoUrl) {
    if (localPath != null && localPath.isNotEmpty) {
      return FileImage(File(localPath));
    }

    if (resolvedPhotoUrl.isNotEmpty) {
      return NetworkImage(resolvedPhotoUrl);
    }

    return null;
  }
}
