import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
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
  late Future<_OpportunityFormData> _initialData;

  String? _token;
  int? _selectedTypeId;
  String _selectedContactMethod = _contactMethods.first;
  bool _isSaving = false;
  String? _errorMessage;

  bool get _isEditing => widget.opportunity != null;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
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

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;

    if (types.isNotEmpty) {
      _selectedTypeId ??= types.first.id;
    }

    return _OpportunityFormData(
      types: types,
      instruments: instruments,
      styles: styles,
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar anuncio' : 'Crear anuncio'),
      ),
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
      padding: const EdgeInsets.all(24),
      children: [
        _OpportunitySection(
          title: 'Tipo',
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedTypeId,
              decoration: const InputDecoration(labelText: 'Tipo de anuncio'),
              items: data.types
                  .map(
                    (type) => DropdownMenuItem<int>(
                      value: type.id,
                      child: Text(type.name),
                    ),
                  )
                  .toList(),
              onChanged: _isEditing
                  ? null
                  : (value) {
                      if (value == null) return;

                      setState(() {
                        _selectedTypeId = value;
                      });
                    },
            ),
          ],
        ),
        _OpportunitySection(
          title: 'Datos basicos',
          children: [
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Titulo'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Descripcion'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Ciudad'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provinceController,
              decoration: const InputDecoration(labelText: 'Provincia'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _eventDateController,
              decoration: const InputDecoration(
                labelText: 'Fecha',
                helperText: 'Formato: YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Precio'),
            ),
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
                      child: Text(method),
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
            TextField(
              controller: _contactValueController,
              decoration: const InputDecoration(labelText: 'Contacto'),
            ),
          ],
        ),
        _OpportunitySection(
          title: 'Instrumentos',
          children: [
            _buildCatalogChips(data.instruments, _selectedInstrumentIds),
          ],
        ),
        _OpportunitySection(
          title: 'Estilos',
          children: [_buildCatalogChips(data.styles, _selectedStyleIds)],
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _save(data),
          child: Text(
            _isSaving
                ? (_isEditing ? 'Guardando...' : 'Creando...')
                : (_isEditing ? 'Guardar cambios' : 'Crear anuncio'),
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
}

class _OpportunitySection extends StatelessWidget {
  const _OpportunitySection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 8),
          const Divider(),
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
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
}
