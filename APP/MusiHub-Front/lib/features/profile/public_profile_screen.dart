import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/contact_action_tile.dart';
import 'package:musihub_front/features/bands/band_detail_screen.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class PublicProfileScreen extends StatefulWidget {
  const PublicProfileScreen({
    super.key,
    required this.tokenStore,
    required this.userId,
  });

  final TokenStore tokenStore;
  final int userId;

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _apiClient = ApiClient();

  late final ProfileApi _profileApi;
  late Future<PublicProfile> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileApi = ProfileApi(apiClient: _apiClient);
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<PublicProfile> _loadProfile() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    return _profileApi.getPublicProfile(token: token, userId: widget.userId);
  }

  void _retryLoad() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _openBand(PublicProfileBand band) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            BandDetailScreen(tokenStore: widget.tokenStore, bandId: band.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil publico')),
      body: SafeArea(
        child: FutureBuilder<PublicProfile>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _PublicProfileView(
                data: snapshot.data!,
                onBandTap: _openBand,
              );
            }

            if (snapshot.hasError) {
              return _PublicProfileLoadError(onRetry: _retryLoad);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _PublicProfileView extends StatelessWidget {
  const _PublicProfileView({required this.data, required this.onBandTap});

  final PublicProfile data;
  final ValueChanged<PublicProfileBand> onBandTap;

  @override
  Widget build(BuildContext context) {
    final profile = data.profile;
    final location = _locationText(profile?.city, profile?.province);
    final bio = _textOrNull(profile?.bio);
    final websiteUrl = _textOrNull(profile?.websiteUrl);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      children: [
        Row(
          children: [
            _PublicAvatar(photoUrl: profile?.photoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  _PublicRoleBadge(role: data.user.role),
                  if (location != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      location,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (profile == null)
          const _PublicEmptyProfile()
        else ...[
          if (bio != null)
            _PublicSection(title: 'Sobre mi', children: [Text(bio)]),
          if (websiteUrl != null)
            _PublicSection(
              title: 'Enlace',
              children: [
                ContactActionTile(method: 'website', value: websiteUrl),
              ],
            ),
          _PublicSection(
            title: 'Informacion musical',
            children: [
              if (profile.instruments.isNotEmpty) ...[
                Text(
                  'Instrumentos',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _PublicChipWrap(
                  items: profile.instruments
                      .map(
                        (instrument) => instrument.isPrimary
                            ? '${instrument.name} principal'
                            : instrument.name,
                      )
                      .toList(),
                ),
              ],
              if (profile.styles.isNotEmpty) ...[
                if (profile.instruments.isNotEmpty) const SizedBox(height: 16),
                Text('Estilos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _PublicChipWrap(
                  items: profile.styles.map((style) => style.name).toList(),
                ),
              ],
              if (profile.instruments.isEmpty && profile.styles.isEmpty)
                const Text('Sin informacion musical visible.'),
            ],
          ),
        ],
        _PublicSection(
          title: 'Bandas visibles',
          children: [
            if (data.bands.isEmpty)
              const Text('No muestra bandas en su perfil.')
            else
              for (final band in data.bands) ...[
                _PublicBandTile(band: band, onTap: () => onBandTap(band)),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ],
    );
  }

  String? _textOrNull(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  String? _locationText(String? city, String? province) {
    final parts = [
      _textOrNull(city),
      _textOrNull(province),
    ].whereType<String>().toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }
}

class _PublicAvatar extends StatelessWidget {
  const _PublicAvatar({required this.photoUrl});

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

class _PublicRoleBadge extends StatelessWidget {
  const _PublicRoleBadge({required this.role});

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

class _PublicEmptyProfile extends StatelessWidget {
  const _PublicEmptyProfile();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text('Este usuario todavia no ha completado su perfil.'),
    );
  }
}

class _PublicSection extends StatelessWidget {
  const _PublicSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 3, height: 22, color: MusiHubColors.primary),
          const SizedBox(height: 8),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }
}

class _PublicBandTile extends StatelessWidget {
  const _PublicBandTile({required this.band, required this.onTap});

  final PublicProfileBand band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final resolvedPhotoUrl = ApiConfig.publicFileUrl(band.photoUrl);
    final location = [
      band.city,
      band.province,
    ].whereType<String>().where((value) => value.isNotEmpty).join(', ');

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 21,
                backgroundColor: MusiHubColors.fieldGrey,
                backgroundImage: resolvedPhotoUrl.isEmpty
                    ? null
                    : NetworkImage(resolvedPhotoUrl),
                child: resolvedPhotoUrl.isEmpty
                    ? const Icon(Icons.groups_outlined, color: Colors.black54)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      band.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      band.roleInBand,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (location.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        location,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
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

class _PublicChipWrap extends StatelessWidget {
  const _PublicChipWrap({required this.items});

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
              backgroundColor: MusiHubColors.primary.withValues(alpha: 0.72),
              labelStyle: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PublicProfileLoadError extends StatelessWidget {
  const _PublicProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No se pudo cargar el perfil publico.',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}
