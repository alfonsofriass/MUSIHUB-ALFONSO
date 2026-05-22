import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/alerts/alerts_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  static const _frequencies = ['immediate', 'daily', 'weekly'];

  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _selectedTypeIds = <int>{};
  final _apiClient = ApiClient();

  late final AlertsApi _alertsApi;
  late final OpportunitiesApi _opportunitiesApi;
  late Future<_AlertsData> _initialDataFuture;

  String? _token;
  String _selectedFrequency = _frequencies.first;
  bool _notificationsEnabled = true;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _alertsApi = AlertsApi(apiClient: _apiClient);
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
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

    final typesFuture = _opportunitiesApi.listOpportunityTypes();
    final preferencesFuture = _alertsApi.getPreferences(token);
    final alertsFuture = _alertsApi.listMyAlerts(token);

    final types = await typesFuture;
    final preferencesResponse = await preferencesFuture;
    final alerts = await alertsFuture;

    _applyPreferences(preferencesResponse.preferences);

    return _AlertsData(types: types, alerts: alerts);
  }

  void _applyPreferences(AlertPreferences? preferences) {
    _cityController.text = preferences?.preferredCity ?? '';
    _provinceController.text = preferences?.preferredProvince ?? '';
    _notificationsEnabled = preferences?.notificationsEnabled ?? true;
    _selectedFrequency = preferences?.frequency ?? _frequencies.first;
    _selectedTypeIds
      ..clear()
      ..addAll(
        preferences?.opportunityTypes.map((type) => type.id) ?? const <int>[],
      );
  }

  Future<void> _savePreferences(_AlertsData data) async {
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
          frequency: _selectedFrequency,
          preferredCity: _textOrNull(_cityController.text),
          preferredProvince: _textOrNull(_provinceController.text),
          notificationsEnabled: _notificationsEnabled,
          opportunityTypeIds: _selectedTypeIds.toList(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _applyPreferences(preferences);
        _successMessage = 'Preferencias guardadas.';
      });

      _refreshAlerts(data);
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

  Future<void> _refreshAlerts(_AlertsData data) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final alerts = await _alertsApi.listMyAlerts(token);

      if (!mounted) return;

      setState(() {
        _initialDataFuture = Future.value(
          _AlertsData(types: data.types, alerts: alerts),
        );
      });
    } catch (_) {
      // Guardar preferencias y refrescar alertas son operaciones distintas.
      // Si el refresco falla, no debe mostrarse como error de guardado.
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

  Future<void> _openCreateOpportunity() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      bottomNavigationBar: OpportunityFeedBottomNav(
        selectedIndex: 3,
        onHome: _goHome,
        onPublish: _openCreateOpportunity,
        onSaved: () {},
        onProfile: _openProfile,
      ),
    );
  }

  Widget _buildContent(_AlertsData data) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
      children: [
        Text('Alertas', style: Theme.of(context).textTheme.headlineLarge),
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
        Text(
          'Frecuencia de alertas',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 12),
        for (final frequency in _frequencies) ...[
          _FrequencyOption(
            title: _frequencyLabel(frequency),
            subtitle: _frequencySubtitle(frequency),
            selected: _selectedFrequency == frequency,
            onTap: () {
              setState(() {
                _selectedFrequency = frequency;
              });
            },
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 14),
        _AlertConfigCard(
          title: 'Ubicacion',
          subtitle: 'Filtra por ciudad o provincia si quieres alertas locales',
          children: [
            TextField(
              controller: _cityController,
              decoration: const InputDecoration(labelText: 'Ciudad preferida'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provinceController,
              decoration: const InputDecoration(
                labelText: 'Provincia preferida',
              ),
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
        _MusicalProfileCard(onEditProfile: _openProfile),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isSaving ? null : () => _savePreferences(data),
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
        const SizedBox(height: 26),
        _AlertsSection(
          title: 'Alertas generadas',
          children: data.alerts.isEmpty
              ? [const _EmptyAlerts()]
              : data.alerts
                    .map(
                      (alert) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _GeneratedAlertCard(
                          alert: alert,
                          onTap: () => _openOpportunity(alert),
                        ),
                      ),
                    )
                    .toList(),
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

  String _frequencyLabel(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Diaria';
      case 'weekly':
        return 'Semanal';
      default:
        return 'Inmediata';
    }
  }

  String _frequencySubtitle(String frequency) {
    switch (frequency) {
      case 'daily':
        return 'Recibe un resumen diario';
      case 'weekly':
        return 'Recibe un resumen semanal';
      default:
        return 'Justo en el momento';
    }
  }
}

class _AlertsData {
  const _AlertsData({required this.types, required this.alerts});

  final List<OpportunityType> types;
  final List<GeneratedAlert> alerts;
}

class _AlertsSection extends StatelessWidget {
  const _AlertsSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
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

class _FrequencyOption extends StatelessWidget {
  const _FrequencyOption({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
            color: selected ? MusiHubColors.primary : MusiHubColors.borderGrey,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 3),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            if (selected)
              const Icon(Icons.check, size: 20, color: MusiHubColors.primary),
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

class _MusicalProfileCard extends StatelessWidget {
  const _MusicalProfileCard({required this.onEditProfile});

  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return _AlertConfigCard(
      title: 'Coincidencia musical',
      subtitle: 'Instrumentos y estilos se calculan desde tu perfil musical.',
      children: [
        OutlinedButton(
          onPressed: onEditProfile,
          child: const Text('Editar perfil musical'),
        ),
      ],
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      alert.reason,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                _dateLabel(alert.createdAt),
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

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }

    final localDate = date.toLocal();
    return '${_twoDigits(localDate.day)}/${_twoDigits(localDate.month)}/${localDate.year}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _ScoreBadge extends StatelessWidget {
  const _ScoreBadge({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: MusiHubColors.primary,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        '$score',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Todavia no hay alertas generadas.',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
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
