import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/contact_action_tile.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
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
  late final LocationsApi _locationsApi;
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
    _locationsApi = LocationsApi(apiClient: _apiClient);
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
    _contactValueController.text = opportunity.contactValue ?? '';
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
    final locationsFuture = _locationsApi.listLocations();
    final profileFuture = _profileApi.getMyProfile(token);

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final bands = await bandsFuture;
    final locations = await locationsFuture;
    final profileMe = await profileFuture;

    if (types.isNotEmpty) {
      _selectedTypeId ??= types.first.id;
    }

    return _OpportunityFormData(
      types: types,
      instruments: instruments,
      styles: styles,
      bands: bands,
      locations: locations,
      profile: profileMe.profile,
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

    final selectedType = type!;
    final template = _OpportunityFormTemplate.fromTypeCode(selectedType.code);
    final eventDate = template.showEventDate
        ? _textOrNull(_eventDateController.text)
        : null;
    final priceAmount = template.showPrice
        ? _priceOrNull(_priceController.text)
        : null;
    final instrumentIds = template.showInstruments
        ? _selectedInstrumentIds.toList()
        : <int>[];
    final styleIds = template.showStyles ? _selectedStyleIds.toList() : <int>[];

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
            province: _provinceController.text.trim(),
            eventDate: eventDate,
            priceAmount: priceAmount,
            contactMethod: _selectedContactMethod,
            contactValue: _contactValueController.text.trim(),
            instrumentIds: instrumentIds,
            styleIds: styleIds,
            includeNullValues: true,
          ),
        );
      } else {
        await _opportunitiesApi.createOpportunity(
          token: token,
          request: OpportunitySaveRequest(
            typeId: selectedType.id,
            authorBandId: _selectedAuthorBandId,
            title: _titleController.text.trim(),
            description: _descriptionController.text.trim(),
            city: _cityController.text.trim(),
            province: _provinceController.text.trim(),
            eventDate: eventDate,
            priceAmount: priceAmount,
            contactMethod: _selectedContactMethod,
            contactValue: _contactValueController.text.trim(),
            instrumentIds: instrumentIds,
            styleIds: styleIds,
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

    final template = _OpportunityFormTemplate.fromTypeCode(type.code);

    if (_textOrNull(_titleController.text) == null ||
        _textOrNull(_descriptionController.text) == null ||
        _textOrNull(_cityController.text) == null ||
        _textOrNull(_provinceController.text) == null ||
        _textOrNull(_contactValueController.text) == null) {
      return 'Completa titulo, descripcion, ubicacion y contacto.';
    }

    if (template.showPrice &&
        _textOrNull(_priceController.text) != null &&
        _priceOrNull(_priceController.text) == null) {
      return 'El precio debe ser un numero valido.';
    }

    final contactError = _validateContactValue();
    if (contactError != null) {
      return contactError;
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

  String? _validateContactValue() {
    final contactValue = _contactValueController.text.trim();

    switch (_selectedContactMethod) {
      case 'whatsapp':
      case 'phone':
        return _isValidPhoneLikeValue(contactValue)
            ? null
            : 'Introduce un telefono valido.';
      case 'email':
        return _isValidEmailValue(contactValue)
            ? null
            : 'Introduce un email valido.';
      default:
        return null;
    }
  }

  bool _isValidPhoneLikeValue(String value) {
    final phonePattern = RegExp(r'^\+?[0-9][0-9\s-]{7,18}$');
    return phonePattern.hasMatch(value);
  }

  bool _isValidEmailValue(String value) {
    final emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    return emailPattern.hasMatch(value);
  }

  String _contactHintText() {
    switch (_selectedContactMethod) {
      case 'email':
        return 'Ej: contacto@email.com';
      case 'other':
        return 'Ej: Instagram @musihub';
      default:
        return 'Ej: 600000000';
    }
  }

  TextInputType _contactKeyboardType() {
    switch (_selectedContactMethod) {
      case 'email':
        return TextInputType.emailAddress;
      case 'whatsapp':
      case 'phone':
        return TextInputType.phone;
      default:
        return TextInputType.text;
    }
  }

  List<TextInputFormatter>? _contactInputFormatters() {
    switch (_selectedContactMethod) {
      case 'whatsapp':
      case 'phone':
        return InputLimits.phoneFormatters;
      default:
        return null;
    }
  }

  int _contactMaxLength() {
    switch (_selectedContactMethod) {
      case 'email':
        return InputLimits.email;
      case 'whatsapp':
      case 'phone':
        return InputLimits.phone;
      default:
        return InputLimits.contactValue;
    }
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
    final selectedType = _selectedType(data.types);
    final template = _OpportunityFormTemplate.fromTypeCode(selectedType?.code);

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
              maxLength: InputLimits.opportunityTitle,
            ),
            const SizedBox(height: 12),
            _buildTextField(
              label: 'Descripcion',
              controller: _descriptionController,
              hintText: 'Describe que ofreces o que buscas',
              maxLength: InputLimits.opportunityDescription,
              maxLines: 3,
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
            if (template.showEventDate) ...[
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Fecha',
                controller: _eventDateController,
                helperText: 'Formato: YYYY-MM-DD',
                maxLength: InputLimits.date,
                inputFormatters: InputLimits.dateFormatters,
              ),
            ],
            if (template.showPrice) ...[
              const SizedBox(height: 12),
              _buildTextField(
                label: 'Precio',
                controller: _priceController,
                hintText: 'Ej: 55',
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                maxLength: InputLimits.price,
                inputFormatters: InputLimits.priceFormatters,
                suffixText: 'EUR',
              ),
            ],
          ],
        ),
        if (template.showStyles)
          _OpportunitySection(
            title: 'Estilo musical',
            children: [
              _buildCatalogDropdown(
                label: 'Selecciona estilo',
                items: data.styles,
                selectedIds: _selectedStyleIds,
              ),
              const SizedBox(height: 6),
              const _SelectionOrderHint(),
            ],
          ),
        if (template.showInstruments)
          _OpportunitySection(
            title: 'Instrumentos',
            children: [
              _buildCatalogDropdown(
                label: 'Selecciona instrumentos',
                items: data.instruments,
                selectedIds: _selectedInstrumentIds,
              ),
              const SizedBox(height: 6),
              const _SelectionOrderHint(),
            ],
          ),
        _OpportunitySection(
          title: 'Contacto',
          children: [
            _buildProfileContactShortcuts(data.profile),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(_selectedContactMethod),
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
              hintText: _contactHintText(),
              keyboardType: _contactKeyboardType(),
              maxLength: _contactMaxLength(),
              inputFormatters: _contactInputFormatters(),
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

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < types.length; index++) ...[
            _OpportunityTypePill(
              label: opportunityTypeFilterLabel(types[index]),
              selected: _selectedTypeId == types[index].id,
              enabled: !_isEditing,
              onTap: () => _selectType(types[index]),
            ),
            if (index < types.length - 1) const SizedBox(width: 14),
          ],
        ],
      ),
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

  Widget _buildProfileContactShortcuts(UserProfile? profile) {
    final contactEmail = _textOrNull(profile?.contactEmail ?? '');
    final contactPhone = _textOrNull(profile?.contactPhone ?? '');

    if (contactEmail == null && contactPhone == null) {
      return Text(
        'Puedes guardar email o telefono en tu perfil para rellenarlo aqui.',
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Usar contacto del perfil',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (contactEmail != null)
          ContactActionTile(
            method: 'email',
            value: contactEmail,
            title: 'Usar email del perfil',
            trailingIcon: Icons.add_circle_outline,
            onTap: () => _useProfileContact('email', contactEmail),
          ),
        if (contactEmail != null && contactPhone != null)
          const SizedBox(height: 8),
        if (contactPhone != null)
          ContactActionTile(
            method: 'phone',
            value: contactPhone,
            title: 'Usar telefono del perfil',
            trailingIcon: Icons.add_circle_outline,
            onTap: () => _useProfileContact('phone', contactPhone),
          ),
      ],
    );
  }

  void _useProfileContact(String method, String value) {
    setState(() {
      _selectedContactMethod = method;
      _contactValueController.text = value;
    });
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    String? helperText,
    String? suffixText,
    int maxLines = 1,
    int? maxLength,
    bool showCounter = false,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      maxLength: maxLength,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        helperText: helperText,
        suffixText: suffixText,
        counterText: maxLength == null || showCounter ? null : '',
      ),
    );
  }

  Widget _buildCatalogDropdown({
    required String label,
    required List<CatalogItem> items,
    required Set<int> selectedIds,
  }) {
    if (items.isEmpty) {
      return const Text('No hay elementos disponibles.');
    }

    final selectedLabel = _selectedCatalogLabel(items, selectedIds);

    return InkWell(
      onTap: () => _openCatalogSelector(
        title: label,
        items: items,
        selectedIds: selectedIds,
      ),
      borderRadius: BorderRadius.circular(8),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label),
        child: Row(
          children: [
            Expanded(
              child: Text(
                selectedLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selectedIds.isEmpty ? MusiHubColors.textGrey : null,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down),
          ],
        ),
      ),
    );
  }

  Future<void> _openCatalogSelector({
    required String title,
    required List<CatalogItem> items,
    required Set<int> selectedIds,
  }) async {
    final updatedSelection = Set<int>.from(selectedIds);

    final shouldApply = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(title),
              content: SizedBox(
                width: double.maxFinite,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 420),
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      for (final item in items)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(item.name),
                          value: updatedSelection.contains(item.id),
                          onChanged: (value) {
                            setDialogState(() {
                              if (value == true) {
                                updatedSelection.add(item.id);
                              } else {
                                updatedSelection.remove(item.id);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancelar'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Aplicar'),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldApply != true) {
      return;
    }

    setState(() {
      selectedIds
        ..clear()
        ..addAll(updatedSelection);
    });
  }

  String _selectedCatalogLabel(List<CatalogItem> items, Set<int> selectedIds) {
    if (selectedIds.isEmpty) {
      return 'Sin seleccionar';
    }

    return items
        .where((item) => selectedIds.contains(item.id))
        .map((item) => item.name)
        .join(', ');
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

  void _selectType(OpportunityType type) {
    final template = _OpportunityFormTemplate.fromTypeCode(type.code);

    setState(() {
      _selectedTypeId = type.id;

      if (!template.showEventDate) {
        _eventDateController.clear();
      }
      if (!template.showPrice) {
        _priceController.clear();
      }
      if (!template.showInstruments) {
        _selectedInstrumentIds.clear();
      }
      if (!template.showStyles) {
        _selectedStyleIds.clear();
      }
    });
  }
}

class _OpportunityTypePill extends StatelessWidget {
  const _OpportunityTypePill({
    required this.label,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected ? MusiHubColors.primary : Colors.transparent;

    return Material(
      color: Colors.white,
      elevation: enabled ? 4 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.18),
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(11),
        child: Container(
          constraints: const BoxConstraints(minWidth: 84),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            border: Border.all(color: borderColor, width: selected ? 2 : 1),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthorBandOption {
  const _AuthorBandOption({required this.id, required this.name});

  final int id;
  final String name;
}

class _OpportunityFormTemplate {
  const _OpportunityFormTemplate({
    required this.showEventDate,
    required this.showPrice,
    required this.showInstruments,
    required this.showStyles,
  });

  final bool showEventDate;
  final bool showPrice;
  final bool showInstruments;
  final bool showStyles;

  factory _OpportunityFormTemplate.fromTypeCode(String? code) {
    switch (code) {
      case 'bolos_sustituciones':
        return const _OpportunityFormTemplate(
          showEventDate: true,
          showPrice: true,
          showInstruments: true,
          showStyles: true,
        );
      case 'busqueda_miembros':
        return const _OpportunityFormTemplate(
          showEventDate: false,
          showPrice: false,
          showInstruments: true,
          showStyles: true,
        );
      case 'eventos':
        return const _OpportunityFormTemplate(
          showEventDate: true,
          showPrice: true,
          showInstruments: false,
          showStyles: true,
        );
      case 'compraventa':
        return const _OpportunityFormTemplate(
          showEventDate: false,
          showPrice: true,
          showInstruments: true,
          showStyles: false,
        );
      case 'clases':
      default:
        return const _OpportunityFormTemplate(
          showEventDate: false,
          showPrice: true,
          showInstruments: true,
          showStyles: true,
        );
    }
  }
}

class _SelectionOrderHint extends StatelessWidget {
  const _SelectionOrderHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      'La primera seleccion aparecera en la portada del anuncio.',
      style: Theme.of(context).textTheme.bodySmall,
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
    required this.locations,
    required this.profile,
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<Band> bands;
  final List<LocationProvince> locations;
  final UserProfile? profile;
}
