import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/search/search_api.dart';

class BandInviteMemberScreen extends StatefulWidget {
  const BandInviteMemberScreen({
    super.key,
    required this.tokenStore,
    required this.band,
  });

  final TokenStore tokenStore;
  final Band band;

  @override
  State<BandInviteMemberScreen> createState() => _BandInviteMemberScreenState();
}

class _BandInviteMemberScreenState extends State<BandInviteMemberScreen> {
  final _memberSearchController = TextEditingController();
  final _selectedInstrumentIds = <int>{};
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late final SearchApi _searchApi;
  late Future<List<CatalogItem>> _instrumentsFuture;
  Future<List<ProfileSearchResult>>? _profileResultsFuture;

  late Band _band;
  String? _token;
  String _submittedQuery = '';
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _searchApi = SearchApi(apiClient: _apiClient);
    _band = widget.band;
    _instrumentsFuture = _loadInstruments();
  }

  @override
  void dispose() {
    _memberSearchController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<List<CatalogItem>> _loadInstruments() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;
    return _profileApi.listInstruments();
  }

  Future<List<ProfileSearchResult>> _searchProfiles(String query) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    final memberIds = _band.members.map((member) => member.userId).toSet();
    final profiles = await _searchApi.searchProfiles(
      token: token,
      query: query,
    );

    return profiles
        .where((profile) => !memberIds.contains(profile.user.id))
        .toList();
  }

  void _submitProfileSearch() {
    final query = _memberSearchController.text.trim();

    setState(() {
      _errorMessage = null;
      _submittedQuery = query;
      _profileResultsFuture = query.isEmpty ? null : _searchProfiles(query);
    });
  }

  void _refreshProfileSearch() {
    final query = _submittedQuery;

    if (query.isEmpty) {
      return;
    }

    setState(() {
      _profileResultsFuture = _searchProfiles(query);
    });
  }

  Future<void> _addMember({
    required ProfileSearchResult profile,
    required List<CatalogItem> instruments,
  }) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    if (_selectedInstrumentIds.isEmpty) {
      setState(() {
        _errorMessage = 'Selecciona al menos un instrumento antes de anadir.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final updatedBand = await _bandsApi.addBandMember(
        token: token,
        bandId: _band.id,
        request: BandMemberSaveRequest(
          userId: profile.user.id,
          roleInBand: _selectedInstrumentNames(instruments).join(', '),
          isVisibleInProfile: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _band = updatedBand;
        _selectedInstrumentIds.clear();
      });
      _refreshProfileSearch();
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No se pudo anadir el miembro. Revisa el ID o permisos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _removeMember(BandMember member) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    try {
      await _bandsApi.removeBandMember(
        token: token,
        bandId: _band.id,
        userId: member.userId,
      );

      if (!mounted) return;

      setState(() {
        _band = Band(
          id: _band.id,
          name: _band.name,
          bio: _band.bio,
          city: _band.city,
          province: _band.province,
          photoUrl: _band.photoUrl,
          createdByUserId: _band.createdByUserId,
          createdAt: _band.createdAt,
          styles: _band.styles,
          members: _band.members
              .where((currentMember) => currentMember.userId != member.userId)
              .toList(),
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo eliminar el miembro.';
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _instrumentsFuture = _loadInstruments();
    });
  }

  List<String> _selectedInstrumentNames(List<CatalogItem> instruments) {
    return instruments
        .where((instrument) => _selectedInstrumentIds.contains(instrument.id))
        .map((instrument) => instrument.name)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;

        Navigator.of(context).pop(true);
      },
      child: Scaffold(
        appBar: AppBar(title: const Text('Invitar miembros')),
        body: SafeArea(
          child: FutureBuilder<List<CatalogItem>>(
            future: _instrumentsFuture,
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return _buildContent(snapshot.data!);
              }

              if (snapshot.hasError) {
                return _InviteMemberLoadError(onRetry: _retryLoad);
              }

              return const Center(child: CircularProgressIndicator());
            },
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<CatalogItem> instruments) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        Text(_band.name, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        _InviteSection(
          title: 'Anadir miembro',
          children: [
            Text(
              'Papel en la banda',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _buildInstrumentChips(instruments),
            const SizedBox(height: 18),
            Text(
              'Buscar perfil',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _memberSearchController,
              maxLength: InputLimits.shortText,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submitProfileSearch(),
              decoration: InputDecoration(
                labelText: 'Nombre del usuario',
                hintText: 'Buscar por nombre...',
                counterText: '',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  onPressed: _submitProfileSearch,
                  icon: const Icon(Icons.arrow_forward),
                  tooltip: 'Buscar perfil',
                ),
              ),
            ),
            const SizedBox(height: 12),
            _buildProfileResults(instruments),
          ],
        ),
        _InviteSection(
          title: 'Miembros(${_band.members.length})',
          children: _band.members.isEmpty
              ? [const Text('Todavia no hay miembros visibles.')]
              : _band.members
                    .map(
                      (member) => _InviteMemberTile(
                        member: member,
                        canRemove: member.userId != _band.createdByUserId,
                        onRemove: () => _removeMember(member),
                      ),
                    )
                    .toList(),
        ),
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }

  Widget _buildInstrumentChips(List<CatalogItem> instruments) {
    if (instruments.isEmpty) {
      return const Text('No hay instrumentos disponibles.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: instruments.map((instrument) {
        final isSelected = _selectedInstrumentIds.contains(instrument.id);

        return FilterChip(
          label: Text(instrument.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedInstrumentIds.add(instrument.id);
              } else {
                _selectedInstrumentIds.remove(instrument.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildProfileResults(List<CatalogItem> instruments) {
    final resultsFuture = _profileResultsFuture;

    if (_submittedQuery.isEmpty || resultsFuture == null) {
      return const Text('Busca un perfil por nombre para anadirlo a la banda.');
    }

    return FutureBuilder<List<ProfileSearchResult>>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final profiles = snapshot.data!;

          if (profiles.isEmpty) {
            return const Text(
              'No hay perfiles disponibles para esta busqueda.',
            );
          }

          return Column(
            children: profiles
                .map(
                  (profile) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ProfileInviteTile(
                      profile: profile,
                      isSaving: _isSaving,
                      onAdd: () => _addMember(
                        profile: profile,
                        instruments: instruments,
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        }

        if (snapshot.hasError) {
          return Text(
            'No se pudieron buscar perfiles.',
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          );
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _InviteSection extends StatelessWidget {
  const _InviteSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileInviteTile extends StatelessWidget {
  const _ProfileInviteTile({
    required this.profile,
    required this.isSaving,
    required this.onAdd,
  });

  final ProfileSearchResult profile;
  final bool isSaving;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final resolvedPhotoUrl = ApiConfig.publicFileUrl(profile.photoUrl);
    final tags = [
      if (_locationText(profile.city, profile.province) != null)
        _locationText(profile.city, profile.province)!,
      ...profile.instruments.take(2).map((instrument) => instrument.name),
      ...profile.styles.take(2).map((style) => style.name),
    ];

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: MusiHubColors.fieldGrey,
              backgroundImage: resolvedPhotoUrl.isEmpty
                  ? null
                  : NetworkImage(resolvedPhotoUrl),
              child: resolvedPhotoUrl.isEmpty
                  ? const Icon(
                      Icons.person_outline,
                      color: MusiHubColors.primary,
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.user.fullName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    profile.bio ?? 'Perfil musical',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 7,
                      runSpacing: 7,
                      children: tags
                          .map((tag) => _ProfileTag(label: tag))
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: isSaving ? null : onAdd,
              icon: const Icon(Icons.add_circle_outline),
              color: MusiHubColors.primary,
              tooltip: 'Anadir a la banda',
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  const _ProfileTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _InviteMemberTile extends StatelessWidget {
  const _InviteMemberTile({
    required this.member,
    required this.canRemove,
    required this.onRemove,
  });

  final BandMember member;
  final bool canRemove;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
      title: Text(
        member.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium,
      ),
      subtitle: Text(member.roleInBand),
      trailing: canRemove
          ? IconButton(
              onPressed: onRemove,
              icon: const Icon(Icons.close),
              tooltip: 'Eliminar miembro',
            )
          : null,
    );
  }
}

String? _locationText(String? city, String? province) {
  final parts = [
    city?.trim(),
    province?.trim(),
  ].whereType<String>().where((part) => part.isNotEmpty).toList();

  return parts.isEmpty ? null : parts.join(', ');
}

class _InviteMemberLoadError extends StatelessWidget {
  const _InviteMemberLoadError({required this.onRetry});

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
              'No se pudo cargar el formulario.',
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
