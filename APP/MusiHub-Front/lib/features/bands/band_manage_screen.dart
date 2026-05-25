import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
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
  final _selectedStyleIds = <int>{};
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late Future<List<CatalogItem>> _stylesFuture;

  String? _token;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _applyBand(widget.band);
    _stylesFuture = _loadStyles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
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

  Future<List<CatalogItem>> _loadStyles() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;
    return _profileApi.listMusicStyles();
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
      _stylesFuture = _loadStyles();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Configuracion'), centerTitle: true),
      body: SafeArea(
        child: FutureBuilder<List<CatalogItem>>(
          future: _stylesFuture,
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

  Widget _buildForm(List<CatalogItem> styles) {
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
              maxLength: InputLimits.shortText,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Descripcion',
              controller: _bioController,
              maxLength: InputLimits.bandBio,
              maxLines: 4,
              showCounter: true,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Ciudad',
              controller: _cityController,
              maxLength: InputLimits.shortText,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Provincia',
              controller: _provinceController,
              maxLength: InputLimits.shortText,
            ),
          ],
        ),
        _BandManageSection(
          title: 'Estilo musical',
          children: [_buildStyleChips(styles)],
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
    int? maxLength,
    bool showCounter = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: maxLength == null || showCounter ? null : '',
      ),
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
