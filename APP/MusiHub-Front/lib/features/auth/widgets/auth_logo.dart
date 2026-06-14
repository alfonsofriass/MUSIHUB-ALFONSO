import 'package:flutter/material.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';

class MusiHubLogoMark extends StatelessWidget {
  const MusiHubLogoMark({super.key, this.size = 78});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.24),
      child: Image.asset(
        'assets/images/musihub_logo_icon.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
        semanticLabel: 'Logo de MusiHub',
        errorBuilder: (context, error, stackTrace) => _LogoFallback(size: size),
      ),
    );
  }
}

class _LogoFallback extends StatelessWidget {
  const _LogoFallback({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(size * 0.24),
      ),
      child: Icon(
        Icons.music_note_rounded,
        color: Colors.black,
        size: size * 0.56,
      ),
    );
  }
}
