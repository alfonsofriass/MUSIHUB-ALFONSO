import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/musihub_empty_state.dart';
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

  Future<void> _reopenOpportunity(Opportunity opportunity) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _opportunitiesApi.reopenOpportunity(
        token: token,
        id: opportunity.id,
      );

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo reabrir el anuncio.')),
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
              final activeCount = opportunities
                  .where((opportunity) => opportunity.isActive)
                  .length;
              final closedCount = opportunities.length - activeCount;

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                children: [
                  Text(
                    'Mis anuncios',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Gestiona las publicaciones que has creado en MusiHub.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 18),
                  if (opportunities.isEmpty)
                    MusiHubEmptyState(
                      icon: Icons.campaign_outlined,
                      title: 'Todavia no tienes anuncios',
                      message:
                          'Publica tu primera oportunidad para que aparezca en la comunidad.',
                      action: FilledButton.icon(
                        onPressed: _openCreateOpportunity,
                        icon: const Icon(Icons.add),
                        label: const Text('Publicar anuncio'),
                      ),
                    )
                  else ...[
                    _MyOpportunitiesSummary(
                      totalCount: opportunities.length,
                      activeCount: activeCount,
                      closedCount: closedCount,
                    ),
                    const SizedBox(height: 18),
                  ],
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
                      onReopen: opportunity.isActive
                          ? null
                          : () => _reopenOpportunity(opportunity),
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

class _MyOpportunitiesSummary extends StatelessWidget {
  const _MyOpportunitiesSummary({
    required this.totalCount,
    required this.activeCount,
    required this.closedCount,
  });

  final int totalCount;
  final int activeCount;
  final int closedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MusiHubColors.primary.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          _SummaryMetric(label: 'Total', value: totalCount),
          const _SummaryDivider(),
          _SummaryMetric(label: 'Activos', value: activeCount),
          const _SummaryDivider(),
          _SummaryMetric(label: 'Cerrados', value: closedCount),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value.toString(),
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(color: MusiHubColors.primary),
          ),
          const SizedBox(height: 2),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _SummaryDivider extends StatelessWidget {
  const _SummaryDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      width: 1,
      color: MusiHubColors.primary.withValues(alpha: 0.18),
    );
  }
}

class _MyOpportunityCard extends StatelessWidget {
  const _MyOpportunityCard({
    required this.opportunity,
    required this.onOpen,
    required this.onEdit,
    required this.onClose,
    required this.onReopen,
  });

  final Opportunity opportunity;
  final VoidCallback onOpen;
  final VoidCallback? onEdit;
  final VoidCallback? onClose;
  final VoidCallback? onReopen;

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
                  if (onReopen != null)
                    IconButton(
                      onPressed: onReopen,
                      icon: const Icon(Icons.lock_open_outlined),
                      tooltip: 'Reabrir anuncio',
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
