import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class OpportunityFormScreen extends StatefulWidget {
  const OpportunityFormScreen({
    super.key,
    required this.tokenStore,
    this.opportunity,
  });

  final TokenStore tokenStore;
  final Opportunity? opportunity;

  @override
  State<OpportunityFormScreen> createState() => _OpportunityFormScreenState();
}

class _OpportunityFormScreenState extends State<OpportunityFormScreen> {
  static const _publishAsMeValue = -1;
  static const _contactMethods = ['whatsapp', 'email', 'phone', 'other'];

  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _eventDateController = TextEditingController();
  final _priceController = TextEditingController();
  final _contactValueController = TextEditingController();
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late final ProfileApi _profileApi;
  late final BandsApi _bandsApi;
  late Future<_OpportunityFormData> _initialData;

  String? _token;
  int? _selectedTypeId;
  int? _selectedAuthorBandId;
  String _selectedContactMethod = _contactMethods.first;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.opportunity != null;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _bandsApi = BandsApi(apiClient: _apiClient);
    _applyOpportunity(widget.opportunity);
    _initialData = _loadInitialData();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _eventDateController.dispose();
    _priceController.dispose();
    _contactValueController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _applyOpportunity(Opportunity? opportunity) {
    if (opportunity == null) {
      return;
    }

    _selectedTypeId = opportunity.type.id;
    _selectedAuthorBandId = opportunity.authorBand?.id;
    _titleController.text = opportunity.title;
    _descriptionController.text = opportunity.description;
    _cityController.text = opportunity.city;
    _provinceController.text = opportunity.province ?? '';
    _eventDateController.text = opportunity.eventDate ?? '';
    _priceController.text = opportunity.priceAmount ?? '';
    _selectedContactMethod = opportunity.contactMethod;
    _contactValueController.text = opportunity.contactValue;
    _selectedInstrumentIds
      ..clear()
      ..addAll(opportunity.instruments.map((item) => item.id));
    _selectedStyleIds
      ..clear()
      ..addAll(opportunity.styles.map((item) => item.id));
  }

  Future<_OpportunityFormData> _loadInitialData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    final typesFuture = _opportunitiesApi.listOpportunityTypes();
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final bandsFuture = _bandsApi.listMyBands(token);

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final bands = await bandsFuture;

    if (types.isNotEmpty) {
      _selectedTypeId ??= types.first.id;
    }

    return _OpportunityFormData(
      types: types,
      instruments: instruments,
      styles: styles,
      bands: bands,
    );
  }

  Future<void> _save(_OpportunityFormData data) async {
    final token = _token;
    final type = _selectedType(data.types);

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
      });
      return;
    }

    final validationError = _validate(type);
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
      if (_isEditing) {
        await _opportunitiesApi.updateOpportunity(
          token: token,
          id: widget.opportunity!.id,
          request: OpportunityUpdateRequest(
            authorBandId: _selectedAuthorBandId,
            includeAuthorBandId: true,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            city: _cityController.text.trim(),
            province: _textOrNull(_provinceController.text),
            eventDate: _textOrNull(_eventDateController.text),
            priceAmount: _priceOrNull(_priceController.text),
            contactMethod: _selectedContactMethod,
            contactValue: _contactValueController.text.trim(),
            instrumentIds: _selectedInstrumentIds.toList(),
            styleIds: _selectedStyleIds.toList(),
            includeNullValues: true,
          ),
        );
      } else {
        await _opportunitiesApi.createOpportunity(
          token: token,
          request: OpportunitySaveRequest(
            typeId: type!.id,
            authorBandId: _selectedAuthorBandId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            city: _cityController.text.trim(),
            province: _textOrNull(_provinceController.text),
            eventDate: _textOrNull(_eventDateController.text),
            priceAmount: _priceOrNull(_priceController.text),
            contactMethod: _selectedContactMethod,
            contactValue: _contactValueController.text.trim(),
            instrumentIds: _selectedInstrumentIds.toList(),
            styleIds: _selectedStyleIds.toList(),
          ),
        );
      }

      if (!mounted) return;

      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = _isEditing
            ? 'No se pudo actualizar el anuncio. Revisa los datos.'
            : 'No se pudo crear el anuncio. Revisa los datos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _validate(OpportunityType? type) {
    if (type == null) {
      return 'No hay tipos de anuncio disponibles.';
    }

    if (_textOrNull(_titleController.text) == null ||
        _textOrNull(_descriptionController.text) == null ||
        _textOrNull(_cityController.text) == null ||
        _textOrNull(_contactValueController.text) == null) {
      return 'Completa titulo, descripcion, ciudad y contacto.';
    }

    if (type.code == 'bolos_sustituciones') {
      if (_textOrNull(_eventDateController.text) == null) {
        return 'Este tipo de anuncio necesita fecha.';
      }
      if (_selectedInstrumentIds.isEmpty) {
        return 'Este tipo de anuncio necesita al menos un instrumento.';
      }
    }

    if (type.code == 'busqueda_miembros' && _selectedInstrumentIds.isEmpty) {
      return 'Este tipo de anuncio necesita al menos un instrumento.';
    }

    if (type.code == 'eventos' &&
        _textOrNull(_eventDateController.text) == null) {
      return 'Este tipo de anuncio necesita fecha.';
    }

    if (type.code == 'compraventa' &&
        _priceOrNull(_priceController.text) == null) {
      return 'Este tipo de anuncio necesita precio.';
    }

    return null;
  }

  OpportunityType? _selectedType(List<OpportunityType> types) {
    for (final type in types) {
      if (type.id == _selectedTypeId) {
        return type;
      }
    }

    return null;
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  num? _priceOrNull(String value) {
    final trimmed = value.trim().replaceAll(',', '.');

    if (trimmed.isEmpty) {
      return null;
    }

    return num.tryParse(trimmed);
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _initialData = _loadInitialData();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Editar anuncio' : 'Publicar')),
      body: SafeArea(
        child: FutureBuilder<_OpportunityFormData>(
          future: _initialData,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildForm(snapshot.data!);
            }

            if (snapshot.hasError) {
              return _OpportunityFormLoadError(onRetry: _retryLoad);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildForm(_OpportunityFormData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 24),
      children: [
        _OpportunitySection(
          title: 'Tipo de anuncio',
          children: [_buildTypeSelector(data.types)],
        ),
        _OpportunitySection(
          title: 'Publicar como',
          children: [_buildAuthorSelector(data.bands)],
        ),
        _OpportunitySection(
          title: 'Informacion basica',
          children: [
            _buildTextField(
              label: 'Titulo del anuncio',
              controller: _titleController,
              hintText: 'Ej: Clases de guitarra',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Descripcion',
              controller: _descriptionController,
              hintText: 'Describe que ofreces o que buscas',
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Ciudad',
              controller: _cityController,
              hintText: 'Ej: Madrid',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Provincia',
              controller: _provinceController,
              hintText: 'Ej: Madrid',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Fecha',
              controller: _eventDateController,
              helperText: 'Formato: YYYY-MM-DD',
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Precio',
              controller: _priceController,
              hintText: 'Ej: 55',
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              suffixText: 'EUR',
            ),
          ],
        ),
        _OpportunitySection(
          title: 'Estilo musical',
          children: [_buildCatalogChips(data.styles, _selectedStyleIds)],
        ),
        _OpportunitySection(
          title: 'Instrumentos',
          children: [
            _buildCatalogChips(data.instruments, _selectedInstrumentIds),
          ],
        ),
        _OpportunitySection(
          title: 'Contacto',
          children: [
            DropdownButtonFormField<String>(
              initialValue: _selectedContactMethod,
              decoration: const InputDecoration(labelText: 'Metodo'),
              items: _contactMethods
                  .map(
                    (method) => DropdownMenuItem<String>(
                      value: method,
                      child: Text(_contactMethodLabel(method)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;

                setState(() {
                  _selectedContactMethod = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Contacto',
              controller: _contactValueController,
              hintText: 'Ej: 600000000',
            ),
          ],
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(data),
          child: Text(
            _isSaving
                ? (_isEditing ? 'Guardando...' : 'Creando...')
                : (_isEditing ? 'Guardar cambios' : 'Publicar'),
          ),
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

  Widget _buildTypeSelector(List<OpportunityType> types) {
    if (types.isEmpty) {
      return const Text('No hay tipos de anuncio disponibles.');
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: types.map((type) {
        return ChoiceChip(
          label: Text(opportunityTypeFilterLabel(type)),
          selected: _selectedTypeId == type.id,
          onSelected: _isEditing
              ? null
              : (_) {
                  setState(() {
                    _selectedTypeId = type.id;
                  });
                },
        );
      }).toList(),
    );
  }

  Widget _buildAuthorSelector(List<Band> bands) {
    final currentAuthorBand = widget.opportunity?.authorBand;
    final bandOptions = bands
        .map((band) => _AuthorBandOption(id: band.id, name: band.name))
        .toList();

    if (currentAuthorBand != null &&
        !bandOptions.any((band) => band.id == currentAuthorBand.id)) {
      bandOptions.add(
        _AuthorBandOption(
          id: currentAuthorBand.id,
          name: currentAuthorBand.name,
        ),
      );
    }

    return DropdownButtonFormField<int>(
      initialValue: _selectedAuthorBandId ?? _publishAsMeValue,
      decoration: const InputDecoration(labelText: 'Publicar como'),
      items: [
        const DropdownMenuItem<int>(
          value: _publishAsMeValue,
          child: Text('Yo'),
        ),
        for (final band in bandOptions)
          DropdownMenuItem<int>(value: band.id, child: Text(band.name)),
      ],
      onChanged: (value) {
        setState(() {
          _selectedAuthorBandId = value == _publishAsMeValue ? null : value;
        });
      },
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    String? suffixText,
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        suffixText: suffixText,
      ),
    );
  }

  Widget _buildCatalogChips(List<CatalogItem> items, Set<int> selectedIds) {
    if (items.isEmpty) {
      return const Text('No hay elementos disponibles.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) {
        final isSelected = selectedIds.contains(item.id);

        return FilterChip(
          label: Text(item.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                selectedIds.add(item.id);
              } else {
                selectedIds.remove(item.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  String _contactMethodLabel(String method) {
    switch (method) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Telefono';
      default:
        return 'Otro';
    }
  }
}

class _AuthorBandOption {
  const _AuthorBandOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _OpportunitySection extends StatelessWidget {
  const _OpportunitySection({required this.title, required this.children});

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

class _OpportunityFormLoadError extends StatelessWidget {
  const _OpportunityFormLoadError({required this.onRetry});

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

class _OpportunityFormData {
  const _OpportunityFormData({
    required this.types,
    required this.instruments,
    required this.styles,
    required this.bands,
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<Band> bands;
}
