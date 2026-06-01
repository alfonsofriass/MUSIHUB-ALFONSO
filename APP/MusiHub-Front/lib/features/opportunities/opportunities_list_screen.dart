import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/favorite_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';
import 'package:musihub_front/features/search/search_screen.dart';

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

  late final AuthApi _authApi;
  late final OpportunitiesApi _opportunitiesApi;
  late final ProfileApi _profileApi;
  late final LocationsApi _locationsApi;
  late Future<OpportunityFilterData> _filterDataFuture;
  late Future<_OpportunityFeedData> _feedDataFuture;

  OpportunityFilters _filters = const OpportunityFilters();
  int? _selectedTypeId;
  int? _selectedInstrumentId;
  int? _selectedStyleId;
  bool _filtersExpanded = false;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
    _filterDataFuture = _loadFilterData();
    _feedDataFuture = _loadFeedData();
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
    final locationsFuture = _locationsApi.listLocations();

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final locations = await locationsFuture;

    return OpportunityFilterData(
      types: types,
      instruments: instruments,
      styles: styles,
      locations: locations,
    );
  }

  Future<_OpportunityFeedData> _loadFeedData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    final opportunitiesFuture = _opportunitiesApi.listOpportunities(
      filters: _filters,
    );
    final favoritesFuture = _opportunitiesApi.listFavoriteOpportunities(token);
    final userFuture = _authApi.me(token);

    final opportunities = await opportunitiesFuture;
    final favorites = await favoritesFuture;
    final user = await userFuture;
    final visibleOpportunities = opportunities
        .where((opportunity) => opportunity.authorUserId != user.id)
        .toList();

    return _OpportunityFeedData(
      opportunities: visibleOpportunities,
      favoriteIds: favorites.map((opportunity) => opportunity.id).toSet(),
    );
  }

  void _refresh() {
    setState(() {
      _feedDataFuture = _loadFeedData();
    });
  }

  Future<void> _openDetail(Opportunity opportunity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpportunityDetailScreen(
          opportunityId: opportunity.id,
          initialOpportunity: opportunity,
          tokenStore: widget.tokenStore,
        ),
      ),
    );

    if (!mounted) return;

    _refresh();
  }

  Future<void> _openCreateOpportunity() async {
    final wasCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (wasCreated != true || !mounted) return;

    _refresh();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anuncio publicado. Puedes verlo en Mis anuncios.'),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _openFavorites() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            FavoriteOpportunitiesScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (!mounted) return;

    _refresh();
  }

  Future<void> _openSearch() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SearchScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _toggleFavorite(Opportunity opportunity, bool isFavorite) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      if (isFavorite) {
        await _opportunitiesApi.removeFavorite(
          token: token,
          opportunityId: opportunity.id,
        );
      } else {
        await _opportunitiesApi.saveFavorite(
          token: token,
          opportunityId: opportunity.id,
        );
      }

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el favorito.')),
      );
    }
  }

  void _retryFilters() {
    setState(() {
      _filterDataFuture = _loadFilterData();
    });
  }

  void _applyFilters() {
    final validationError = _filterValidationError();
    if (validationError != null) {
      _showFilterError(validationError);
      return;
    }

    setState(() {
      _filters = _currentFilters();
      _feedDataFuture = _loadFeedData();
    });
  }

  void _applyTypeFilter(int? typeId) {
    final previousTypeId = _selectedTypeId;
    _selectedTypeId = typeId;

    final validationError = _filterValidationError();
    if (validationError != null) {
      _selectedTypeId = previousTypeId;
      _showFilterError(validationError);
      return;
    }

    setState(() {
      _filters = _currentFilters();
      _feedDataFuture = _loadFeedData();
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
      _feedDataFuture = _loadFeedData();
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

  DateTime? _dateOrNull(String value) {
    final trimmed = value.trim();

    if (trimmed.isEmpty) {
      return null;
    }

    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(trimmed);
    if (match == null) {
      return null;
    }

    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final parsed = DateTime.tryParse(trimmed);

    if (parsed == null ||
        parsed.year != year ||
        parsed.month != month ||
        parsed.day != day) {
      return null;
    }

    return parsed;
  }

  String? _filterValidationError() {
    final dateFromText = _textOrNull(_dateFromController.text);
    final dateToText = _textOrNull(_dateToController.text);
    final minPriceText = _textOrNull(_minPriceController.text);
    final maxPriceText = _textOrNull(_maxPriceController.text);
    final dateFrom = _dateOrNull(_dateFromController.text);
    final dateTo = _dateOrNull(_dateToController.text);
    final minPrice = _priceOrNull(_minPriceController.text);
    final maxPrice = _priceOrNull(_maxPriceController.text);

    if ((dateFromText != null && dateFrom == null) ||
        (dateToText != null && dateTo == null)) {
      return 'Usa fechas con formato YYYY-MM-DD.';
    }

    if (dateFrom != null && dateTo != null && dateFrom.isAfter(dateTo)) {
      return 'La fecha desde no puede ser posterior a la fecha hasta.';
    }

    if ((minPriceText != null && minPrice == null) ||
        (maxPriceText != null && maxPrice == null)) {
      return 'El precio debe ser un numero valido.';
    }

    if (minPrice != null && maxPrice != null && minPrice > maxPrice) {
      return 'El precio minimo no puede superar al precio maximo.';
    }

    return null;
  }

  void _showFilterError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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
            OpportunitySearchPlaceholder(onTap: _openSearch),
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
            FutureBuilder<_OpportunityFeedData>(
              future: _feedDataFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  final data = snapshot.data!;

                  return OpportunityFeedResults(
                    opportunities: data.opportunities,
                    favoriteIds: data.favoriteIds,
                    hasFilters: _filters.hasFilters,
                    onOpen: _openDetail,
                    onFavoriteTap: (opportunity) => _toggleFavorite(
                      opportunity,
                      data.favoriteIds.contains(opportunity.id),
                    ),
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
        onSaved: _openFavorites,
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
        const SizedBox(height: 14),
        const _FeedSectionDivider(),
      ],
    );
  }
}

class _FeedSectionDivider extends StatelessWidget {
  const _FeedSectionDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.38),
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _OpportunityFeedData {
  const _OpportunityFeedData({
    required this.opportunities,
    required this.favoriteIds,
  });

  final List<Opportunity> opportunities;
  final Set<int> favoriteIds;
}
