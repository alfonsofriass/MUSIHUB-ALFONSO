import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/formatters/date_formatters.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/core/widgets/musihub_empty_state.dart';
import 'package:musihub_front/features/alerts/alerts_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

enum AlertsScreenMode { generated, settings }

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({
    super.key,
    required this.tokenStore,
    this.mode = AlertsScreenMode.generated,
  });

  final TokenStore tokenStore;
  final AlertsScreenMode mode;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const _immediateFrequency = 'immediate';

  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _selectedTypeIds = <int>{};
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};
  final _apiClient = ApiClient();

  late final AlertsApi _alertsApi;
  late final OpportunitiesApi _opportunitiesApi;
  late final ProfileApi _profileApi;
  late final LocationsApi _locationsApi;
  late Future<_AlertsData> _initialDataFuture;

  String? _token;
  bool _notificationsEnabled = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _alertsApi = AlertsApi(apiClient: _apiClient);
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
    _initialDataFuture = _loadInitialData();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _provinceController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<_AlertsData> _loadInitialData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    if (widget.mode == AlertsScreenMode.generated) {
      final alerts = await _alertsApi.listMyAlerts(token);

      return _AlertsData(
        types: const [],
        instruments: const [],
        styles: const [],
        locations: const [],
        alerts: alerts,
      );
    }

    final typesFuture = _opportunitiesApi.listOpportunityTypes();
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final locationsFuture = _locationsApi.listLocations();
    final preferencesFuture = _alertsApi.getPreferences(token);

    final types = await typesFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final locations = await locationsFuture;
    final preferencesResponse = await preferencesFuture;

    _applyPreferences(preferencesResponse.preferences);

    return _AlertsData(
      types: types,
      instruments: instruments,
      styles: styles,
      locations: locations,
      alerts: const [],
    );
  }

  void _applyPreferences(AlertPreferences? preferences) {
    _cityController.text = preferences?.preferredCity ?? '';
    _provinceController.text = preferences?.preferredProvince ?? '';
    _notificationsEnabled = preferences?.notificationsEnabled ?? true;
    _selectedTypeIds
      ..clear()
      ..addAll(
        preferences?.opportunityTypes.map((type) => type.id) ?? const <int>[],
      );
    _selectedInstrumentIds
      ..clear()
      ..addAll(
        preferences?.instruments.map((instrument) => instrument.id) ??
            const <int>[],
      );
    _selectedStyleIds
      ..clear()
      ..addAll(preferences?.styles.map((style) => style.id) ?? const <int>[]);
  }

  Future<void> _savePreferences() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final preferences = await _alertsApi.savePreferences(
        token: token,
        request: AlertPreferencesSaveRequest(
          frequency: _immediateFrequency,
          preferredCity: _textOrNull(_cityController.text),
          preferredProvince: _textOrNull(_provinceController.text),
          notificationsEnabled: _notificationsEnabled,
          opportunityTypeIds: _selectedTypeIds.toList(),
          instrumentIds: _selectedInstrumentIds.toList(),
          styleIds: _selectedStyleIds.toList(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _applyPreferences(preferences);
        _successMessage = 'Preferencias guardadas.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudieron guardar las alertas.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _initialDataFuture = _loadInitialData();
    });
  }

  Future<void> _openOpportunity(GeneratedAlert alert) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpportunityDetailScreen(
          opportunityId: alert.opportunity.id,
          initialOpportunity: alert.opportunity,
          tokenStore: widget.tokenStore,
        ),
      ),
    );

    if (!mounted) return;

    _retryLoad();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: FutureBuilder<_AlertsData>(
          future: _initialDataFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _buildContent(snapshot.data!);
            }

            if (snapshot.hasError) {
              return _AlertsLoadError(onRetry: _retryLoad);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }

  Widget _buildContent(_AlertsData data) {
    if (widget.mode == AlertsScreenMode.generated) {
      return _buildGeneratedAlertsContent(data);
    }

    return _buildSettingsContent(data);
  }

  Widget _buildSettingsContent(_AlertsData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
      children: [
        Text(
          'Configurar alertas',
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 18),
        _ActivationCard(
          enabled: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
        const SizedBox(height: 22),
        _AlertConfigCard(
          title: 'Ubicacion',
          subtitle: 'Filtra por ciudad o provincia si quieres alertas locales',
          children: [
            LocationSelector(
              locations: data.locations,
              provinceController: _provinceController,
              cityController: _cityController,
              provinceLabel: 'Provincia preferida',
              cityLabel: 'Ciudad preferida',
              requireProvince: false,
              requireCity: false,
            ),
          ],
        ),
        const SizedBox(height: 18),
        _AlertConfigCard(
          title: 'Tipo de anuncio',
          subtitle: 'Selecciona que tipos de anuncios te interesan',
          children: [_buildTypeChips(data.types)],
        ),
        const SizedBox(height: 18),
        _AlertConfigCard(
          title: 'Instrumentos',
          subtitle:
              'Elige instrumentos de interes. Si no eliges ninguno, no se filtra por instrumento.',
          children: [
            _buildCatalogChips(data.instruments, _selectedInstrumentIds),
          ],
        ),
        const SizedBox(height: 18),
        _AlertConfigCard(
          title: 'Estilos musicales',
          subtitle:
              'Elige estilos de interes. Si no eliges ninguno, no se filtra por estilo.',
          children: [_buildCatalogChips(data.styles, _selectedStyleIds)],
        ),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isSaving ? null : _savePreferences,
          child: Text(_isSaving ? 'Guardando...' : 'Guardar alertas'),
        ),
        if (_successMessage != null) ...[
          const SizedBox(height: 12),
          Text(
            _successMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
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
      return const Text('No hay opciones disponibles.');
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

  Widget _buildGeneratedAlertsContent(_AlertsData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
      children: [
        Text('Mis alertas', style: Theme.of(context).textTheme.headlineLarge),
        const SizedBox(height: 6),
        Text(
          'Oportunidades que encajan con tu perfil y preferencias.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        const _AlertScoreInfo(),
        const SizedBox(height: 18),
        if (data.alerts.isEmpty)
          const _EmptyAlerts()
        else
          for (final alert in data.alerts)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _GeneratedAlertCard(
                alert: alert,
                onTap: () => _openOpportunity(alert),
              ),
            ),
      ],
    );
  }

  Widget _buildTypeChips(List<OpportunityType> types) {
    if (types.isEmpty) {
      return const Text('No hay tipos disponibles.');
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: types.map((type) {
        final isSelected = _selectedTypeIds.contains(type.id);

        return FilterChip(
          label: Text(type.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedTypeIds.add(type.id);
              } else {
                _selectedTypeIds.remove(type.id);
              }
            });
          },
        );
      }).toList(),
    );
  }
}

class _AlertsData {
  const _AlertsData({
    required this.types,
    required this.instruments,
    required this.styles,
    required this.locations,
    required this.alerts,
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<LocationProvince> locations;
  final List<GeneratedAlert> alerts;
}

class _ActivationCard extends StatelessWidget {
  const _ActivationCard({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MusiHubColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.notifications_none, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    enabled ? 'Alertas activas' : 'Alertas desactivadas',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Recibiras coincidencias segun tus preferencias',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: enabled, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

class _AlertConfigCard extends StatelessWidget {
  const _AlertConfigCard({
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 14),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _AlertScoreInfo extends StatelessWidget {
  const _AlertScoreInfo();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MusiHubColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.auto_awesome_outlined,
            size: 20,
            color: MusiHubColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'La puntuacion resume cuanto encaja el anuncio con tus preferencias, ubicacion e intereses musicales. El motivo explica las coincidencias detectadas.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _GeneratedAlertCard extends StatelessWidget {
  const _GeneratedAlertCard({required this.alert, required this.onTap});

  final GeneratedAlert alert;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final opportunity = alert.opportunity;

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ScoreBadge(score: alert.score),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Motivo de la alerta',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          alert.reason,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                formatLocalDateLabel(alert.createdAt),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              Text(
                opportunity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                opportunity.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _AlertMetaItem(
                    icon: Icons.category_outlined,
                    text: opportunity.type.name,
                  ),
                  _AlertMetaItem(
                    icon: Icons.location_on_outlined,
                    text: opportunity.city,
                  ),
                  if (opportunity.priceAmount != null)
                    _AlertMetaItem(
                      icon: Icons.euro,
                      text: opportunityPriceLabel(opportunity.priceAmount!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: MusiHubColors.primary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            '$score',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Text(
            'pts',
            style: TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _AlertMetaItem extends StatelessWidget {
  const _AlertMetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _EmptyAlerts extends StatelessWidget {
  const _EmptyAlerts();

  @override
  Widget build(BuildContext context) {
    return const MusiHubEmptyState(
      icon: Icons.notifications_none,
      title: 'Todavia no hay alertas',
      message:
          'Cuando se publiquen anuncios que encajen contigo, apareceran aqui.',
    );
  }
}

class _AlertsLoadError extends StatelessWidget {
  const _AlertsLoadError({required this.onRetry});

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
              'No se pudieron cargar las alertas.',
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
