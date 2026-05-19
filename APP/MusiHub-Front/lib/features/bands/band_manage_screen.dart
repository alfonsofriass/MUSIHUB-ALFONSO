import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class BandManageScreen extends StatefulWidget {
  const BandManageScreen({
    super.key,
    required this.tokenStore,
    required this.band,
  });

  final TokenStore tokenStore;
  final Band band;

  @override
  State<BandManageScreen> createState() => _BandManageScreenState();
}

class _BandManageScreenState extends State<BandManageScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _memberUserIdController = TextEditingController();
  final _selectedStyleIds = <int>{};
  final _selectedMemberInstrumentIds = <int>{};
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late Future<_BandManageData> _initialDataFuture;

  late Band _band;
  String? _token;
  bool _isSaving = false;
  bool _isAddingMember = false;
  bool _isNewMemberVisibleInProfile = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _band = widget.band;
    _applyBand(widget.band);
    _initialDataFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _memberUserIdController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _applyBand(Band band) {
    _nameController.text = band.name;
    _bioController.text = band.bio ?? '';
    _cityController.text = band.city ?? '';
    _provinceController.text = band.province ?? '';
    _selectedStyleIds
      ..clear()
      ..addAll(band.styles.map((style) => style.id));
  }

  Future<_BandManageData> _loadInitialData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();

    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;

    return _BandManageData(instruments: instruments, styles: styles);
  }

  Future<void> _save() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    final validationError = _validate();
    if (validationError != null) {
      setState(() {
        _errorMessage = validationError;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _bandsApi.updateBand(
        token: token,
        bandId: widget.band.id,
        request: BandUpdateRequest(
          name: _nameController.text.trim(),
          bio: _textOrNull(_bioController.text),
          city: _cityController.text.trim(),
          province: _provinceController.text.trim(),
          photoUrl: widget.band.photoUrl,
          styleIds: _selectedStyleIds.toList(),
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No se pudo guardar la banda. Revisa los datos o permisos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _addMember(_BandManageData data) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    final userId = int.tryParse(_memberUserIdController.text.trim());
    if (userId == null || _selectedMemberInstrumentIds.isEmpty) {
      setState(() {
        _errorMessage = 'Indica el ID de usuario y al menos un instrumento.';
      });
      return;
    }

    setState(() {
      _isAddingMember = true;
      _errorMessage = null;
    });

    try {
      final updatedBand = await _bandsApi.addBandMember(
        token: token,
        bandId: _band.id,
        request: BandMemberSaveRequest(
          userId: userId,
          roleInBand: _selectedMemberInstrumentNames(
            data.instruments,
          ).join(', '),
          isVisibleInProfile: _isNewMemberVisibleInProfile,
        ),
      );

      if (!mounted) return;

      setState(() {
        _band = updatedBand;
        _applyBand(updatedBand);
        _memberUserIdController.clear();
        _selectedMemberInstrumentIds.clear();
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
          _isAddingMember = false;
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

  String? _validate() {
    if (_textOrNull(_nameController.text) == null ||
        _textOrNull(_cityController.text) == null ||
        _textOrNull(_provinceController.text) == null) {
      return 'Completa nombre, ciudad y provincia.';
    }

    return null;
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _initialDataFuture = _loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gestionar Banda'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<_BandManageData>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildForm(snapshot.data!);
            }

            if (snapshot.hasError) {
              return _BandManageLoadError(onRetry: _retryLoad);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildForm(_BandManageData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        _BandManageAvatar(photoUrl: widget.band.photoUrl),
        const SizedBox(height: 26),
        _BandManageSection(
          title: 'Informacion basica',
          children: [
            _buildTextField(
              label: 'Nombre de la banda',
              controller: _nameController,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Descripcion',
              controller: _bioController,
              maxLines: 4,
            ),
            const SizedBox(height: 12),
            _buildTextField(label: 'Ciudad', controller: _cityController),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Provincia',
              controller: _provinceController,
            ),
          ],
        ),
        _BandManageSection(
          title: 'Estilo musical',
          children: [_buildStyleChips(data.styles)],
        ),
        _BandManageSection(
          title: 'Miembros(${_band.members.length})',
          children: _band.members.isEmpty
              ? [const Text('Todavia no hay miembros visibles.')]
              : _band.members
                    .map(
                      (member) => _ManageMemberTile(
                        member: member,
                        canRemove: member.userId != _band.createdByUserId,
                        onRemove: () => _removeMember(member),
                      ),
                    )
                    .toList(),
        ),
        _BandManageSection(
          title: 'Anadir miembro',
          children: [
            _buildTextField(
              label: 'ID de usuario',
              controller: _memberUserIdController,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            Text(
              'Instrumentos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 10),
            _buildMemberInstrumentChips(data.instruments),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mostrar en perfil del miembro'),
              value: _isNewMemberVisibleInProfile,
              onChanged: (value) {
                setState(() {
                  _isNewMemberVisibleInProfile = value;
                });
              },
            ),
            FilledButton(
              onPressed: _isAddingMember ? null : () => _addMember(data),
              child: Text(_isAddingMember ? 'Anadiendo...' : 'Anadir miembro'),
            ),
          ],
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _buildStyleChips(List<CatalogItem> styles) {
    if (styles.isEmpty) {
      return const Text('No hay estilos disponibles.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: styles.map((style) {
        final isSelected = _selectedStyleIds.contains(style.id);

        return FilterChip(
          label: Text(style.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedStyleIds.add(style.id);
              } else {
                _selectedStyleIds.remove(style.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildMemberInstrumentChips(List<CatalogItem> instruments) {
    if (instruments.isEmpty) {
      return const Text('No hay instrumentos disponibles.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: instruments.map((instrument) {
        final isSelected = _selectedMemberInstrumentIds.contains(instrument.id);

        return FilterChip(
          label: Text(instrument.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedMemberInstrumentIds.add(instrument.id);
              } else {
                _selectedMemberInstrumentIds.remove(instrument.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  List<String> _selectedMemberInstrumentNames(List<CatalogItem> instruments) {
    return instruments
        .where((instrument) {
          return _selectedMemberInstrumentIds.contains(instrument.id);
        })
        .map((instrument) => instrument.name)
        .toList();
  }
}

class _BandManageData {
  const _BandManageData({required this.instruments, required this.styles});

  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
}

class _BandManageAvatar extends StatelessWidget {
  const _BandManageAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: const Color(0xFFD9D9D9),
          backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
          child: photoUrl == null
              ? const Icon(Icons.camera_alt_outlined, size: 30)
              : null,
        ),
        const SizedBox(height: 10),
        Text(
          'La foto se editara mas adelante.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ManageMemberTile extends StatelessWidget {
  const _ManageMemberTile({
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

class _BandManageSection extends StatelessWidget {
  const _BandManageSection({required this.title, required this.children});

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

class _BandManageLoadError extends StatelessWidget {
  const _BandManageLoadError({required this.onRetry});

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
