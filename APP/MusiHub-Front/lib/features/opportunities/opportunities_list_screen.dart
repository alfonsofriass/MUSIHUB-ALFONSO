import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class OpportunitiesListScreen extends StatefulWidget {
  const OpportunitiesListScreen({super.key});

  @override
  State<OpportunitiesListScreen> createState() =>
      _OpportunitiesListScreenState();
}

class _OpportunitiesListScreenState extends State<OpportunitiesListScreen> {
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _dateFromController = TextEditingController();
  final _dateToController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late final ProfileApi _profileApi;
  late Future<_OpportunityFilterData> _filterDataFuture;
  late Future<List<Opportunity>> _opportunitiesFuture;

  OpportunityFilters _filters = const OpportunityFilters();
  int? _selectedTypeId;
  int? _selectedInstrumentId;
  int? _selectedStyleId;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _filterDataFuture = _loadFilterData();
    _opportunitiesFuture = _loadOpportunities();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _provinceController.dispose();
    _dateFromController.dispose();
    _dateToController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<_OpportunityFilterData> _loadFilterData() async {
    final typesFuture = _opportunitiesApi.listOpportunityTypes();
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;

    return _OpportunityFilterData(
      types: types,
      instruments: instruments,
      styles: styles,
    );
  }

  Future<List<Opportunity>> _loadOpportunities() {
    return _opportunitiesApi.listOpportunities(filters: _filters);
  }

  void _refresh() {
    setState(() {
      _opportunitiesFuture = _loadOpportunities();
    });
  }

  Future<void> _openDetail(Opportunity opportunity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpportunityDetailScreen(opportunityId: opportunity.id),
      ),
    );
  }

  void _retryFilters() {
    setState(() {
      _filterDataFuture = _loadFilterData();
    });
  }

  void _applyFilters() {
    setState(() {
      _filters = OpportunityFilters(
        typeId: _selectedTypeId,
        city: _textOrNull(_cityController.text),
        province: _textOrNull(_provinceController.text),
        instrumentId: _selectedInstrumentId,
        styleId: _selectedStyleId,
        dateFrom: _textOrNull(_dateFromController.text),
        dateTo: _textOrNull(_dateToController.text),
        minPrice: _priceOrNull(_minPriceController.text),
        maxPrice: _priceOrNull(_maxPriceController.text),
      );
      _opportunitiesFuture = _loadOpportunities();
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedTypeId = null;
      _selectedInstrumentId = null;
      _selectedStyleId = null;
      _cityController.clear();
      _provinceController.clear();
      _dateFromController.clear();
      _dateToController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _filters = const OpportunityFilters();
      _opportunitiesFuture = _loadOpportunities();
    });
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anuncios'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar anuncios',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            FutureBuilder<_OpportunityFilterData>(
              future: _filterDataFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildFilters(snapshot.data!);
                }

                if (snapshot.hasError) {
                  return _FilterLoadError(onRetry: _retryFilters);
                }

                return const _FilterLoading();
              },
            ),
            const SizedBox(height: 16),
            FutureBuilder<List<Opportunity>>(
              future: _opportunitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildOpportunities(snapshot.data!);
                }

                if (snapshot.hasError) {
                  final message =
                      snapshot.error is InvalidOpportunityFiltersException
                      ? 'Revisa los rangos de fecha o precio.'
                      : 'No se pudieron cargar los anuncios.';

                  return _OpportunitiesLoadError(
                    message: message,
                    onRetry: _refresh,
                  );
                }

                return const Center(child: CircularProgressIndicator());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters(_OpportunityFilterData data) {
    return _FilterSection(
      children: [
        Text('Filtros', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedTypeId,
          decoration: const InputDecoration(labelText: 'Tipo'),
          hint: const Text('Todos los tipos'),
          items: data.types
              .map(
                (type) => DropdownMenuItem<int>(
                  value: type.id,
                  child: Text(type.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedTypeId = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _cityController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Ciudad'),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _provinceController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Provincia'),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedInstrumentId,
          decoration: const InputDecoration(labelText: 'Instrumento'),
          hint: const Text('Todos los instrumentos'),
          items: data.instruments
              .map(
                (instrument) => DropdownMenuItem<int>(
                  value: instrument.id,
                  child: Text(instrument.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedInstrumentId = value;
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          initialValue: _selectedStyleId,
          decoration: const InputDecoration(labelText: 'Estilo'),
          hint: const Text('Todos los estilos'),
          items: data.styles
              .map(
                (style) => DropdownMenuItem<int>(
                  value: style.id,
                  child: Text(style.name),
                ),
              )
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedStyleId = value;
            });
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dateFromController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Fecha desde',
            helperText: 'Formato: YYYY-MM-DD',
          ),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _dateToController,
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(
            labelText: 'Fecha hasta',
            helperText: 'Formato: YYYY-MM-DD',
          ),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _minPriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Precio minimo'),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _maxPriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.search,
          decoration: const InputDecoration(labelText: 'Precio maximo'),
          onSubmitted: (_) => _applyFilters(),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: _applyFilters,
              child: const Text('Aplicar filtros'),
            ),
            OutlinedButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar filtros'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOpportunities(List<Opportunity> opportunities) {
    if (opportunities.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            _filters.hasFilters
                ? 'No hay anuncios para estos filtros.'
                : 'No hay anuncios activos.',
          ),
        ),
      );
    }

    return Column(
      children: [
        for (var index = 0; index < opportunities.length; index++) ...[
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(opportunities[index].title),
            subtitle: Text(_subtitle(opportunities[index])),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _openDetail(opportunities[index]),
          ),
          if (index < opportunities.length - 1) const Divider(),
        ],
      ],
    );
  }

  String _subtitle(Opportunity opportunity) {
    final parts = [
      opportunity.type.name,
      opportunity.city,
      if (opportunity.priceAmount != null) '${opportunity.priceAmount} EUR',
    ];

    return parts.join(' · ');
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [...children, const SizedBox(height: 8), const Divider()],
    );
  }
}

class _FilterLoading extends StatelessWidget {
  const _FilterLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Cargando filtros...'),
      ],
    );
  }
}

class _FilterLoadError extends StatelessWidget {
  const _FilterLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No se pudieron cargar los filtros.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _OpportunitiesLoadError extends StatelessWidget {
  const _OpportunitiesLoadError({required this.message, required this.onRetry});

  final String message;
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
              message,
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

class _OpportunityFilterData {
  const _OpportunityFilterData({
    required this.types,
    required this.instruments,
    required this.styles,
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
}
