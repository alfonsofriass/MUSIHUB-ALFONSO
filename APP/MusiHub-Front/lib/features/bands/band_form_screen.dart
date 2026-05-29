import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class BandFormScreen extends StatefulWidget {
  const BandFormScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<BandFormScreen> createState() => _BandFormScreenState();
}

class _BandFormScreenState extends State<BandFormScreen> {
  final _nameController = TextEditingController();
  final _bioController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late final ProfileApi _profileApi;
  late final LocationsApi _locationsApi;
  late Future<_BandFormData> _initialDataFuture;

  String? _token;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
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

  Future<_BandFormData> _loadInitialData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final locationsFuture = _locationsApi.listLocations();

    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final locations = await locationsFuture;

    return _BandFormData(
      instruments: instruments,
      styles: styles,
      locations: locations,
    );
  }

  Future<void> _save(_BandFormData data) async {
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
      await _bandsApi.createBand(
        token: token,
        request: BandSaveRequest(
          name: _nameController.text.trim(),
          bio: _textOrNull(_bioController.text),
          city: _cityController.text.trim(),
          province: _provinceController.text.trim(),
          photoUrl: null,
          roleInBand: _selectedInstrumentNames(data.instruments).join(', '),
          isVisibleInProfile: true,
          styleIds: _selectedStyleIds.toList(),
        ),
      );

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo crear la banda. Revisa los datos.';
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

    if (_selectedInstrumentIds.isEmpty) {
      return 'Selecciona al menos un instrumento en la banda.';
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
      appBar: AppBar(title: const Text('Crear banda')),
      body: SafeArea(
        child: FutureBuilder<_BandFormData>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildForm(snapshot.data!);
            }

            if (snapshot.hasError) {
              return _BandFormLoadError(onRetry: _retryLoad);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildForm(_BandFormData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        const Center(
          child: CircleAvatar(
            radius: 40,
            backgroundColor: Color(0xFFD9D9D9),
            child: Icon(Icons.camera_alt_outlined, size: 30),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'La foto se anadira mas adelante.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 26),
        _BandFormSection(
          title: 'Informacion basica',
          children: [
            _buildTextField(
              label: 'Nombre de la banda',
              controller: _nameController,
              hintText: 'Ej: Green Music',
              maxLength: InputLimits.shortText,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Descripcion',
              controller: _bioController,
              hintText: 'Cuenta que estilo haceis o que buscais',
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
        _BandFormSection(
          title: 'Tu papel en la banda',
          children: [_buildInstrumentChips(data.instruments)],
        ),
        _BandFormSection(
          title: 'Estilo musical',
          children: [_buildStyleChips(data.styles)],
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(data),
          child: Text(_isSaving ? 'Creando...' : 'Crear banda'),
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
    String? hintText,
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
        hintText: hintText,
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

  List<String> _selectedInstrumentNames(List<CatalogItem> instruments) {
    return instruments
        .where((instrument) => _selectedInstrumentIds.contains(instrument.id))
        .map((instrument) => instrument.name)
        .toList();
  }
}

class _BandFormData {
  const _BandFormData({
    required this.instruments,
    required this.styles,
    required this.locations,
  });

  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<LocationProvince> locations;
}

class _BandFormSection extends StatelessWidget {
  const _BandFormSection({required this.title, required this.children});

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

class _BandFormLoadError extends StatelessWidget {
  const _BandFormLoadError({required this.onRetry});

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
