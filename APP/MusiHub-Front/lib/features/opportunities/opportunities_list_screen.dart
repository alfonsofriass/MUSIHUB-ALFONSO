import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';

class OpportunitiesListScreen extends StatefulWidget {
  const OpportunitiesListScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

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
  late Future<OpportunityFilterData> _filterDataFuture;
  late Future<List<Opportunity>> _opportunitiesFuture;

  OpportunityFilters _filters = const OpportunityFilters();
  int? _selectedTypeId;
  int? _selectedInstrumentId;
  int? _selectedStyleId;
  bool _filtersExpanded = false;

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

  Future<OpportunityFilterData> _loadFilterData() async {
    final typesFuture = _opportunitiesApi.listOpportunityTypes();
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;

    return OpportunityFilterData(
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
        builder: (_) => OpportunityDetailScreen(
          opportunityId: opportunity.id,
          tokenStore: widget.tokenStore,
        ),
      ),
    );
  }

  Future<void> _openCreateOpportunity() async {
    final wasCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (wasCreated != true || !mounted) return;

    _refresh();
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  void _showFutureFeature(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label estara disponible mas adelante.')),
    );
  }

  void _retryFilters() {
    setState(() {
      _filterDataFuture = _loadFilterData();
    });
  }

  void _applyFilters() {
    setState(() {
      _filters = _currentFilters();
      _opportunitiesFuture = _loadOpportunities();
    });
  }

  void _applyTypeFilter(int? typeId) {
    setState(() {
      _selectedTypeId = typeId;
      _filters = _currentFilters();
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

  OpportunityFilters _currentFilters() {
    return OpportunityFilters(
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
          children: [
            Text(
              'Oportunidades',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 10),
            OpportunitySearchPlaceholder(
              onTap: () => _showFutureFeature('La busqueda'),
            ),
            const SizedBox(height: 14),
            FutureBuilder<OpportunityFilterData>(
              future: _filterDataFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _buildFilters(snapshot.data!);
                }

                if (snapshot.hasError) {
                  return OpportunityFilterLoadError(onRetry: _retryFilters);
                }

                return const OpportunityFilterLoading();
              },
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Opportunity>>(
              future: _opportunitiesFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return OpportunityFeedResults(
                    opportunities: snapshot.data!,
                    hasFilters: _filters.hasFilters,
                    onOpen: _openDetail,
                    onFavoriteTap: () => _showFutureFeature('Favoritos'),
                  );
                }

                if (snapshot.hasError) {
                  final message =
                      snapshot.error is InvalidOpportunityFiltersException
                      ? 'Revisa los rangos de fecha o precio.'
                      : 'No se pudieron cargar los anuncios.';

                  return OpportunitiesLoadError(
                    message: message,
                    onRetry: _refresh,
                  );
                }

                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(child: CircularProgressIndicator()),
                );
              },
            ),
          ],
        ),
      ),
      bottomNavigationBar: OpportunityFeedBottomNav(
        onHome: () {},
        onPublish: _openCreateOpportunity,
        onSaved: () => _showFutureFeature('Guardados'),
        onProfile: _openProfile,
      ),
    );
  }

  Widget _buildFilters(OpportunityFilterData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OpportunityQuickTypeFilters(
          types: data.types,
          selectedTypeId: _selectedTypeId,
          onSelected: _applyTypeFilter,
        ),
        const SizedBox(height: 12),
        OpportunityFilterHeader(
          expanded: _filtersExpanded,
          onTap: () {
            setState(() {
              _filtersExpanded = !_filtersExpanded;
            });
          },
        ),
        if (_filtersExpanded) ...[
          const SizedBox(height: 12),
          OpportunityAdvancedFilters(
            data: data,
            selectedTypeId: _selectedTypeId,
            selectedInstrumentId: _selectedInstrumentId,
            selectedStyleId: _selectedStyleId,
            cityController: _cityController,
            provinceController: _provinceController,
            dateFromController: _dateFromController,
            dateToController: _dateToController,
            minPriceController: _minPriceController,
            maxPriceController: _maxPriceController,
            onTypeChanged: (value) {
              setState(() {
                _selectedTypeId = value;
              });
            },
            onInstrumentChanged: (value) {
              setState(() {
                _selectedInstrumentId = value;
              });
            },
            onStyleChanged: (value) {
              setState(() {
                _selectedStyleId = value;
              });
            },
            onApply: _applyFilters,
            onClear: _clearFilters,
          ),
        ],
      ],
    );
  }
}
