import 'package:flutter/material.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/photo_picker_panel.dart';
import 'package:musihub_front/features/bands/bands_api.dart';

class ProfilePhotoEditor extends StatelessWidget {
  const ProfilePhotoEditor({
    super.key,
    required this.photoUrl,
    required this.isUploading,
    required this.onTap,
  });

  final String? photoUrl;
  final bool isUploading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PhotoPickerPanel(
      photoUrl: photoUrl,
      isUploading: isUploading,
      onTap: onTap,
      radius: 38,
      placeholderIcon: Icons.person_outline,
    );
  }
}

class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({super.key, required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    final resolvedPhotoUrl = ApiConfig.publicFileUrl(photoUrl);

    return CircleAvatar(
      radius: 38,
      backgroundColor: MusiHubColors.fieldGrey,
      backgroundImage: resolvedPhotoUrl.isEmpty
          ? null
          : NetworkImage(resolvedPhotoUrl),
      child: resolvedPhotoUrl.isEmpty
          ? const Icon(Icons.person_outline, size: 38, color: Colors.black54)
          : null,
    );
  }
}

class ProfileEmptyState extends StatelessWidget {
  const ProfileEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Perfil pendiente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Completa tu perfil para mostrar instrumentos, estilos y contacto.',
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCreate, child: const Text('Crear perfil')),
        ],
      ),
    );
  }
}

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: MusiHubColors.primary.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        _roleLabel(role),
        style: const TextStyle(
          color: MusiHubColors.primary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _roleLabel(String role) {
    return switch (role) {
      'musico' => 'Musico',
      'venta' => 'Venta',
      'sala_bar' => 'Sala/bar',
      'academia_profesor' => 'Academia/Profesor',
      _ => role,
    };
  }
}

class ActivityActionTile extends StatelessWidget {
  const ActivityActionTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MusiHubColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: MusiHubColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MusiHubColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileSettingsAction extends StatelessWidget {
  const ProfileSettingsAction({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : MusiHubColors.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class ProfileBandTile extends StatelessWidget {
  const ProfileBandTile({super.key, required this.band, required this.onTap});

  final Band band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MusiHubColors.primary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: MusiHubColors.primary.withValues(alpha: 0.55),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 6,
              offset: const Offset(0, 2),
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ],
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.groups_outlined,
                size: 16,
                color: MusiHubColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    band.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (location != null)
                    Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white),
          ],
        ),
      ),
    );
  }

  String? _locationLabel() {
    final parts = [
      band.city,
      band.province,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final label = parts.join(', ');

    return label.isEmpty ? null : label;
  }
}

class ProfileSection extends StatelessWidget {
  const ProfileSection({
    super.key,
    required this.title,
    required this.children,
    this.icon,
  });

  final String title;
  final List<Widget> children;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 18,
                decoration: BoxDecoration(
                  color: MusiHubColors.primary.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 7),
                Icon(icon, size: 17, color: MusiHubColors.primary),
              ],
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 8),
          Divider(
            color: MusiHubColors.primary.withValues(alpha: 0.38),
            thickness: 1,
          ),
        ],
      ),
    );
  }
}

class MusicalInfoLabel extends StatelessWidget {
  const MusicalInfoLabel({super.key, required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MusiHubColors.primary),
        const SizedBox(width: 6),
        Text(label, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class ChipWrap extends StatelessWidget {
  const ChipWrap({super.key, required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              backgroundColor: MusiHubColors.primary.withValues(alpha: 0.75),
              labelStyle: const TextStyle(color: Colors.white),
              side: BorderSide(
                color: MusiHubColors.primary.withValues(alpha: 0.55),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          )
          .toList(),
    );
  }
}
