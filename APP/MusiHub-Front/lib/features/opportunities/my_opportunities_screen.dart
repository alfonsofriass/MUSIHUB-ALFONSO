import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';

class MyOpportunitiesScreen extends StatefulWidget {
  const MyOpportunitiesScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<MyOpportunitiesScreen> createState() => _MyOpportunitiesScreenState();
}

class _MyOpportunitiesScreenState extends State<MyOpportunitiesScreen> {
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late Future<List<Opportunity>> _opportunitiesFuture;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _opportunitiesFuture = _loadOpportunities();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<List<Opportunity>> _loadOpportunities() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    return _opportunitiesApi.listMyOpportunities(token);
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
          initialOpportunity: opportunity,
          tokenStore: widget.tokenStore,
        ),
      ),
    );

    if (!mounted) return;

    _refresh();
  }

  Future<void> _openEditOpportunity(Opportunity opportunity) async {
    final wasUpdated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(
          tokenStore: widget.tokenStore,
          opportunity: opportunity,
        ),
      ),
    );

    if (wasUpdated != true || !mounted) return;

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
  }

  Future<void> _closeOpportunity(Opportunity opportunity) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _opportunitiesApi.closeOpportunity(
        token: token,
        id: opportunity.id,
      );

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo cerrar el anuncio.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis anuncios'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar mis anuncios',
          ),
          IconButton(
            onPressed: _openCreateOpportunity,
            icon: const Icon(Icons.add),
            tooltip: 'Crear anuncio',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Opportunity>>(
          future: _opportunitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final opportunities = snapshot.data!;

              if (opportunities.isEmpty) {
                return const Center(child: Text('Todavia no tienes anuncios.'));
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  for (final opportunity in opportunities) ...[
                    _MyOpportunityCard(
                      opportunity: opportunity,
                      onOpen: () => _openDetail(opportunity),
                      onEdit: opportunity.isActive
                          ? () => _openEditOpportunity(opportunity)
                          : null,
                      onClose: opportunity.isActive
                          ? () => _closeOpportunity(opportunity)
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }

            if (snapshot.hasError) {
              return _MyOpportunitiesLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _MyOpportunityCard extends StatelessWidget {
  const _MyOpportunityCard({
    required this.opportunity,
    required this.onOpen,
    required this.onEdit,
    required this.onClose,
  });

  final Opportunity opportunity;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _MyOpportunityTags(opportunity: opportunity)),
                  _StatusBadge(isActive: opportunity.isActive),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                opportunity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (opportunity.authorBand != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: MusiHubColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        opportunity.authorBand!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: MusiHubColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaText(
                    icon: Icons.location_on_outlined,
                    text: opportunity.city,
                  ),
                  if (opportunity.eventDate != null)
                    _MetaText(
                      icon: Icons.calendar_month_outlined,
                      text: opportunityShortDateLabel(opportunity.eventDate!),
                    ),
                  if (opportunity.priceAmount != null)
                    _MetaText(
                      icon: Icons.euro,
                      text: opportunityPriceLabel(opportunity.priceAmount!),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  TextButton.icon(
                    onPressed: onOpen,
                    icon: const Icon(Icons.visibility_outlined, size: 18),
                    label: const Text('Ver'),
                  ),
                  const Spacer(),
                  if (onEdit != null)
                    IconButton(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Editar anuncio',
                    ),
                  if (onClose != null)
                    IconButton(
                      onPressed: onClose,
                      icon: const Icon(Icons.lock_outline),
                      tooltip: 'Cerrar anuncio',
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

class _MyOpportunityTags extends StatelessWidget {
  const _MyOpportunityTags({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final labels = [
      opportunityTypeTagLabel(opportunity.type),
      if (opportunity.instruments.isNotEmpty)
        opportunity.instruments.first.name,
      if (opportunity.styles.isNotEmpty) opportunity.styles.first.name,
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: labels.map((label) => _SmallBadge(label: label)).toList(),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: MusiHubColors.borderGrey),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: isActive
            ? MusiHubColors.primary.withValues(alpha: 0.16)
            : MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isActive ? 'Activo' : 'Cerrado',
        style: TextStyle(
          color: isActive ? MusiHubColors.primary : MusiHubColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MusiHubColors.textGrey),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _MyOpportunitiesLoadError extends StatelessWidget {
  const _MyOpportunitiesLoadError({required this.onRetry});

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
              'No se pudieron cargar tus anuncios.',
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
