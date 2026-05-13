import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';

class OpportunityDetailScreen extends StatefulWidget {
  const OpportunityDetailScreen({super.key, required this.opportunityId});

  final int opportunityId;

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late Future<Opportunity> _opportunityFuture;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _opportunityFuture = _loadOpportunity();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<Opportunity> _loadOpportunity() {
    return _opportunitiesApi.getOpportunity(widget.opportunityId);
  }

  void _refresh() {
    setState(() {
      _opportunityFuture = _loadOpportunity();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle anuncio'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar anuncio',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<Opportunity>(
          future: _opportunityFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _OpportunityDetail(opportunity: snapshot.data!);
            }

            if (snapshot.hasError) {
              return _OpportunityLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _OpportunityDetail extends StatelessWidget {
  const _OpportunityDetail({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(opportunity.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text('${opportunity.type.name} · ${opportunity.city}'),
        if (opportunity.province != null) Text(opportunity.province!),
        const SizedBox(height: 24),
        Text(opportunity.description),
        const SizedBox(height: 24),
        _DetailRow(label: 'Estado', value: opportunity.status),
        if (opportunity.eventDate != null)
          _DetailRow(label: 'Fecha', value: opportunity.eventDate!),
        if (opportunity.priceAmount != null)
          _DetailRow(label: 'Precio', value: '${opportunity.priceAmount} EUR'),
        _DetailRow(label: 'Contacto', value: opportunity.contactMethod),
        _DetailRow(label: 'Valor contacto', value: opportunity.contactValue),
        if (opportunity.instruments.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Instrumentos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ChipWrap(items: opportunity.instruments.map((item) => item.name)),
        ],
        if (opportunity.styles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Estilos', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          _ChipWrap(items: opportunity.styles.map((item) => item.name)),
        ],
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text('$label: $value'),
    );
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required Iterable<String> items}) : _items = items;

  final Iterable<String> _items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _items.map((item) => Chip(label: Text(item))).toList(),
    );
  }
}

class _OpportunityLoadError extends StatelessWidget {
  const _OpportunityLoadError({required this.onRetry});

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
              'No se pudo cargar el anuncio.',
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
