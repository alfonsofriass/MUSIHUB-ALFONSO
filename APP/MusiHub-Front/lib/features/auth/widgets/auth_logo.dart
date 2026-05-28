import 'package:flutter/material.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';

class MusiHubLogoMark extends StatelessWidget {
  const MusiHubLogoMark({
    super.key,
    this.size = 78,
    this.icon = Icons.music_note_rounded,
  });

  final double size;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      child: Icon(icon, color: Colors.black, size: size * 0.56),
    );
  }
}
