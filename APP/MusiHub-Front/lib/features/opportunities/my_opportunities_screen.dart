import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
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

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: opportunities.length,
                separatorBuilder: (_, _) => const Divider(),
                itemBuilder: (context, index) {
                  final opportunity = opportunities[index];

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(opportunity.title),
                    subtitle: Text(_subtitle(opportunity)),
                    trailing: Wrap(
                      spacing: 4,
                      children: [
                        IconButton(
                          onPressed: () => _openDetail(opportunity),
                          icon: const Icon(Icons.visibility),
                          tooltip: 'Ver anuncio',
                        ),
                        if (opportunity.isActive)
                          IconButton(
                            onPressed: () => _openEditOpportunity(opportunity),
                            icon: const Icon(Icons.edit),
                            tooltip: 'Editar anuncio',
                          ),
                        if (opportunity.isActive)
                          IconButton(
                            onPressed: () => _closeOpportunity(opportunity),
                            icon: const Icon(Icons.lock),
                            tooltip: 'Cerrar anuncio',
                          ),
                      ],
                    ),
                    onTap: () => _openDetail(opportunity),
                  );
                },
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

  String _subtitle(Opportunity opportunity) {
    final parts = [
      opportunity.type.name,
      opportunity.city,
      opportunity.status,
      if (opportunity.priceAmount != null) '${opportunity.priceAmount} EUR',
    ];

    return parts.join(' · ');
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
