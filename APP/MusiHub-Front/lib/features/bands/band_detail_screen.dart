import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/bands/band_invite_member_screen.dart';
import 'package:musihub_front/features/bands/band_manage_screen.dart';
import 'package:musihub_front/features/bands/bands_api.dart';

class BandDetailScreen extends StatefulWidget {
  const BandDetailScreen({
    super.key,
    required this.tokenStore,
    required this.bandId,
  });

  final TokenStore tokenStore;
  final int bandId;

  @override
  State<BandDetailScreen> createState() => _BandDetailScreenState();
}

class _BandDetailScreenState extends State<BandDetailScreen> {
  final _apiClient = ApiClient();

  late final AuthApi _authApi;
  late final BandsApi _bandsApi;
  late Future<_BandDetailData> _bandFuture;

  bool _isUpdatingVisibility = false;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _bandsApi = BandsApi(apiClient: _apiClient);
    _bandFuture = _loadBand();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<_BandDetailData> _loadBand() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    final bandFuture = _bandsApi.getBand(token: token, bandId: widget.bandId);
    final userFuture = _authApi.me(token);

    final band = await bandFuture;
    final user = await userFuture;

    return _BandDetailData(
      band: band,
      canManage: band.createdByUserId == user.id,
      currentUserId: user.id,
    );
  }

  void _refresh() {
    setState(() {
      _bandFuture = _loadBand();
    });
  }

  Future<void> _openManageBand(Band band) async {
    final wasUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            BandManageScreen(tokenStore: widget.tokenStore, band: band),
      ),
    );

    if (wasUpdated != true || !mounted) return;

    _refresh();
  }

  Future<void> _openInviteMembers(Band band) async {
    final wasUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) =>
            BandInviteMemberScreen(tokenStore: widget.tokenStore, band: band),
      ),
    );

    if (wasUpdated != true || !mounted) return;

    _refresh();
  }

  Future<void> _updateMyVisibility({
    required Band band,
    required bool isVisible,
  }) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isUpdatingVisibility = true;
    });

    try {
      await _bandsApi.updateMyBandVisibility(
        token: token,
        bandId: band.id,
        isVisibleInProfile: isVisible,
      );

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo actualizar la visibilidad de la banda.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUpdatingVisibility = false;
        });
      }
    }
  }

  void _showFutureFeature(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label estara disponible mas adelante.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mi Banda'), centerTitle: false),
      body: SafeArea(
        child: FutureBuilder<_BandDetailData>(
          future: _bandFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final data = snapshot.data!;

              return _BandDetail(
                band: data.band,
                canManage: data.canManage,
                currentMember: data.currentMember,
                isUpdatingVisibility: _isUpdatingVisibility,
                onVisibilityChanged: (value) =>
                    _updateMyVisibility(band: data.band, isVisible: value),
                onInviteTap: () => _openInviteMembers(data.band),
                onRequestsTap: () =>
                    _showFutureFeature('Solicitudes pendientes'),
                onSettingsTap: () => _openManageBand(data.band),
              );
            }

            if (snapshot.hasError) {
              return _BandLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _BandDetailData {
  const _BandDetailData({
    required this.band,
    required this.canManage,
    required this.currentUserId,
  });

  final Band band;
  final bool canManage;
  final int currentUserId;

  BandMember? get currentMember {
    for (final member in band.members) {
      if (member.userId == currentUserId &&
          member.membershipStatus == 'accepted') {
        return member;
      }
    }

    return null;
  }
}

class _BandDetail extends StatelessWidget {
  const _BandDetail({
    required this.band,
    required this.canManage,
    required this.currentMember,
    required this.isUpdatingVisibility,
    required this.onVisibilityChanged,
    required this.onInviteTap,
    required this.onRequestsTap,
    required this.onSettingsTap,
  });

  final Band band;
  final bool canManage;
  final BandMember? currentMember;
  final bool isUpdatingVisibility;
  final ValueChanged<bool> onVisibilityChanged;
  final VoidCallback onInviteTap;
  final VoidCallback onRequestsTap;
  final VoidCallback onSettingsTap;

  @override
  Widget build(BuildContext context) {
    final instruments = _memberInstruments();

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 8, 28, 96),
      children: [
        _BandHeader(band: band),
        const SizedBox(height: 18),
        if (currentMember != null)
          _BandSection(
            title: 'Visibilidad',
            children: [
              _BandVisibilityTile(
                isVisible: currentMember!.isVisibleInProfile,
                isUpdating: isUpdatingVisibility,
                onChanged: onVisibilityChanged,
              ),
            ],
          ),
        _BandSection(
          title: 'Sobre la Banda',
          children: [
            Text(
              band.bio?.trim().isNotEmpty == true
                  ? band.bio!.trim()
                  : 'Todavia no hay descripcion de la banda.',
            ),
          ],
        ),
        _BandSection(
          title: 'Miembros',
          children: band.members.isEmpty
              ? [const Text('Todavia no hay miembros visibles.')]
              : band.members
                    .map(
                      (member) => _BandMemberTile(band: band, member: member),
                    )
                    .toList(),
        ),
        _BandSection(
          title: 'Informacion Musical',
          children: [
            Text(
              'Instrumentos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (instruments.isEmpty)
              const Text('Sin instrumentos indicados.')
            else
              _BandChipWrap(items: instruments),
            const SizedBox(height: 18),
            Text(
              'Estilo Musical',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            if (band.styles.isEmpty)
              const Text('Sin estilos indicados.')
            else
              _BandChipWrap(
                items: band.styles.map((style) => style.name).toList(),
              ),
          ],
        ),
        if (canManage)
          _BandSection(
            title: 'Gestionar Banda',
            children: [
              _ManageRow(
                icon: Icons.group_add_outlined,
                label: 'Invitar miembros',
                onTap: onInviteTap,
              ),
              const SizedBox(height: 8),
              _ManageRow(
                icon: Icons.mail_outline,
                label: 'Solicitudes pendientes',
                showDot: true,
                onTap: onRequestsTap,
              ),
              const SizedBox(height: 8),
              _ManageRow(
                icon: Icons.menu_outlined,
                label: 'Configuracion',
                onTap: onSettingsTap,
              ),
            ],
          ),
      ],
    );
  }

  List<String> _memberInstruments() {
    final instruments = <String>{};

    for (final member in band.members) {
      for (final instrument in _splitRoleInBand(member.roleInBand)) {
        instruments.add(instrument);
      }
    }

    return instruments.toList();
  }

  List<String> _splitRoleInBand(String roleInBand) {
    return roleInBand
        .split(RegExp(r'\s*,\s*|\s+y\s+', caseSensitive: false))
        .map((instrument) => instrument.trim())
        .where((instrument) => instrument.isNotEmpty)
        .toList();
  }
}

class _BandHeader extends StatelessWidget {
  const _BandHeader({required this.band});

  final Band band;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(band);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _BandAvatar(photoUrl: band.photoUrl),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(band.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 2),
              Text('Banda', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 6),
              if (location != null)
                _SmallInfo(icon: Icons.location_on_outlined, text: location),
              const SizedBox(height: 6),
              Text(
                '${band.members.length} miembros',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  String? _locationLabel(Band band) {
    final parts = [
      band.city,
      band.province,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final label = parts.join(', ');

    return label.isEmpty ? null : label;
  }
}

class _BandAvatar extends StatelessWidget {
  const _BandAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 38,
      backgroundColor: const Color(0xFFD9D9D9),
      backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      child: photoUrl == null
          ? const Icon(
              Icons.camera_alt_outlined,
              size: 28,
              color: Colors.black87,
            )
          : null,
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: MusiHubColors.textGrey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _BandSection extends StatelessWidget {
  const _BandSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 3, height: 22, color: MusiHubColors.primary),
              const SizedBox(width: 7),
              Text(title, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _BandMemberTile extends StatelessWidget {
  const _BandMemberTile({required this.band, required this.member});

  final Band band;
  final BandMember member;

  @override
  Widget build(BuildContext context) {
    final isCreator = member.userId == band.createdByUserId;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: MusiHubColors.fieldGrey,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: MusiHubColors.borderGrey),
        ),
        child: const Icon(Icons.music_note_outlined),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              member.fullName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (isCreator)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: MusiHubColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Admin',
                style: TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
        ],
      ),
      subtitle: Text(member.roleInBand),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}

class _BandVisibilityTile extends StatelessWidget {
  const _BandVisibilityTile({
    required this.isVisible,
    required this.isUpdating,
    required this.onChanged,
  });

  final bool isVisible;
  final bool isUpdating;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: MusiHubColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.visibility_outlined,
                color: MusiHubColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Mostrar en mi perfil',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Decide si esta banda aparece en tu perfil publico.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: isVisible, onChanged: isUpdating ? null : onChanged),
          ],
        ),
      ),
    );
  }
}

class _BandChipWrap extends StatelessWidget {
  const _BandChipWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              backgroundColor: MusiHubColors.primary.withValues(alpha: 0.75),
              labelStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ManageRow extends StatelessWidget {
  const _ManageRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.showDot = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        height: 42,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: MusiHubColors.borderGrey),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: MusiHubColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label)),
            if (showDot)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(right: 10),
                decoration: const BoxDecoration(
                  color: MusiHubColors.primary,
                  shape: BoxShape.circle,
                ),
              ),
            const Icon(Icons.chevron_right, size: 18),
          ],
        ),
      ),
    );
  }
}

class _BandLoadError extends StatelessWidget {
  const _BandLoadError({required this.onRetry});

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
              'No se pudo cargar la banda.',
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
