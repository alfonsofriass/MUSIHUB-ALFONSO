import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';

class OpportunitiesListScreen extends StatefulWidget {
  const OpportunitiesListScreen({super.key});

  @override
  State<OpportunitiesListScreen> createState() =>
      _OpportunitiesListScreenState();
}

class _OpportunitiesListScreenState extends State<OpportunitiesListScreen> {
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

  Future<List<Opportunity>> _loadOpportunities() {
    return _opportunitiesApi.listOpportunities();
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
        child: FutureBuilder<List<Opportunity>>(
          future: _opportunitiesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final opportunities = snapshot.data!;

              if (opportunities.isEmpty) {
                return const Center(child: Text('No hay anuncios activos.'));
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
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _openDetail(opportunity),
                  );
                },
              );
            }

            if (snapshot.hasError) {
              return _OpportunitiesLoadError(onRetry: _refresh);
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
      if (opportunity.priceAmount != null) '${opportunity.priceAmount} EUR',
    ];

    return parts.join(' · ');
  }
}

class _OpportunitiesLoadError extends StatelessWidget {
  const _OpportunitiesLoadError({required this.onRetry});

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
              'No se pudieron cargar los anuncios.',
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
