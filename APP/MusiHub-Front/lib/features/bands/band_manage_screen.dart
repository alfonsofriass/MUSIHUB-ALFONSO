import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/core/widgets/photo_picker_panel.dart';
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
  final _imagePicker = ImagePicker();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late final LocationsApi _locationsApi;
  late Future<_BandManageData> _initialDataFuture;

  String? _token;
  String? _currentPhotoUrl;
  bool _isSaving = false;
  bool _isDeleting = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
    _applyBand(widget.band);
    _initialDataFuture = _loadInitialData();
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
    _currentPhotoUrl = band.photoUrl;
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
    final stylesFuture = _profileApi.listMusicStyles();
    final locationsFuture = _locationsApi.listLocations();

    final styles = await stylesFuture;
    final locations = await locationsFuture;

    return _BandManageData(styles: styles, locations: locations);
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
          photoUrl: _currentPhotoUrl,
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

  Future<void> _pickAndUploadBandPhoto() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 82,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
        _errorMessage = null;
      });

      final response = await _bandsApi.uploadBandPhoto(
        token: token,
        bandId: widget.band.id,
        file: File(image.path),
      );

      if (!mounted) return;

      setState(() {
        _currentPhotoUrl = response.photoUrl;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de banda actualizada.')),
      );
    } on UnsupportedBandPhotoTypeException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Formato no valido. Usa JPG, PNG o WebP.';
      });
    } on BandPhotoTooLargeException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'La foto no puede superar 5 MB.';
      });
    } on BandPhotoForbiddenException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Solo el creador puede cambiar la foto de la banda.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo subir la foto de la banda.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _deleteBand() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    final confirmed = await _confirmDeleteBand();
    if (confirmed != true) {
      return;
    }

    setState(() {
      _isDeleting = true;
      _errorMessage = null;
    });

    try {
      await _bandsApi.deleteBand(token: token, bandId: widget.band.id);

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } on BandHasMembersException {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No puedes eliminar la banda mientras tenga otros miembros.';
      });
    } on BandDeleteForbiddenException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'Solo el creador puede eliminar esta banda.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo eliminar la banda.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  Future<bool?> _confirmDeleteBand() {
    return showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar banda'),
          content: const Text(
            'Esta accion no se puede deshacer. Los anuncios asociados se conservaran sin banda.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Eliminar'),
            ),
          ],
        );
      },
    );
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
      appBar: AppBar(title: const Text('Configuracion'), centerTitle: true),
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
    final canDeleteBand = widget.band.members.length == 1;

    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        _BandManageAvatar(
          photoUrl: _currentPhotoUrl,
          isUploading: _isUploadingPhoto,
          onTap: _isUploadingPhoto ? null : _pickAndUploadBandPhoto,
        ),
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
            LocationSelector(
              locations: data.locations,
              provinceController: _provinceController,
              cityController: _cityController,
              requireProvince: true,
              requireCity: true,
            ),
          ],
        ),
        _BandManageSection(
          title: 'Estilo musical',
          children: [_buildStyleChips(data.styles)],
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          child: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
        ),
        if (canDeleteBand) ...[
          const SizedBox(height: 18),
          _DeleteBandCard(isDeleting: _isDeleting, onDelete: _deleteBand),
        ],
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
  const _BandManageAvatar({
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
      placeholderIcon: Icons.camera_alt_outlined,
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

class _DeleteBandCard extends StatelessWidget {
  const _DeleteBandCard({required this.isDeleting, required this.onDelete});

  final bool isDeleting;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final errorColor = Theme.of(context).colorScheme.error;

    return Material(
      color: Colors.white,
      elevation: 2,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.delete_outline, color: errorColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Eliminar banda',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Solo disponible si no hay otros miembros.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: isDeleting ? null : onDelete,
              child: Text(isDeleting ? 'Eliminando...' : 'Eliminar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _BandManageData {
  const _BandManageData({required this.styles, required this.locations});

  final List<CatalogItem> styles;
  final List<LocationProvince> locations;
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
