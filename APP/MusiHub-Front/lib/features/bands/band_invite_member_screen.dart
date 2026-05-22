import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

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
  final _memberUserIdController = TextEditingController();
  final _selectedInstrumentIds = <int>{};
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late Future<List<CatalogItem>> _instrumentsFuture;

  late Band _band;
  String? _token;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _band = widget.band;
    _instrumentsFuture = _loadInstruments();
  }

  @override
  void dispose() {
    _memberUserIdController.dispose();
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

  Future<void> _addMember(List<CatalogItem> instruments) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    final userId = int.tryParse(_memberUserIdController.text.trim());
    if (userId == null || _selectedInstrumentIds.isEmpty) {
      setState(() {
        _errorMessage = 'Indica el ID de usuario y al menos un instrumento.';
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
          userId: userId,
          roleInBand: _selectedInstrumentNames(instruments).join(', '),
          isVisibleInProfile: true,
        ),
      );

      if (!mounted) return;

      setState(() {
        _band = updatedBand;
        _memberUserIdController.clear();
        _selectedInstrumentIds.clear();
      });
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
            TextField(
              controller: _memberUserIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'ID de usuario'),
            ),
            const SizedBox(height: 12),
            Text(
              'Instrumentos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _buildInstrumentChips(instruments),
            FilledButton(
              onPressed: _isSaving ? null : () => _addMember(instruments),
              child: Text(_isSaving ? 'Anadiendo...' : 'Anadir miembro'),
            ),
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
