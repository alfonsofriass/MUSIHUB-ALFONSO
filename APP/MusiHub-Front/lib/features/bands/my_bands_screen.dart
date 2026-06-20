import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/config/api_config.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/bands/band_detail_screen.dart';
import 'package:musihub_front/features/bands/band_form_screen.dart';
import 'package:musihub_front/features/bands/bands_api.dart';

class MyBandsScreen extends StatefulWidget {
  const MyBandsScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<MyBandsScreen> createState() => _MyBandsScreenState();
}

class _MyBandsScreenState extends State<MyBandsScreen> {
  final _apiClient = ApiClient();

  late final BandsApi _bandsApi;
  late Future<List<Band>> _bandsFuture;

  @override
  void initState() {
    super.initState();
    _bandsApi = BandsApi(apiClient: _apiClient);
    _bandsFuture = _loadBands();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<List<Band>> _loadBands() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    return _bandsApi.listMyBands(token);
  }

  void _refresh() {
    setState(() {
      _bandsFuture = _loadBands();
    });
  }

  Future<void> _openBand(Band band) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            BandDetailScreen(tokenStore: widget.tokenStore, bandId: band.id),
      ),
    );

    if (!mounted) return;

    _refresh();
  }

  Future<void> _openCreateBand() async {
    final wasCreated = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => BandFormScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (wasCreated != true || !mounted) return;

    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis bandas'),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar bandas',
          ),
          IconButton(
            onPressed: _openCreateBand,
            icon: const Icon(Icons.add),
            tooltip: 'Crear banda',
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<List<Band>>(
          future: _bandsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final bands = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
                children: [
                  Text(
                    'Mis Bandas',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  if (bands.isEmpty)
                    _EmptyBands(onCreateBand: _openCreateBand)
                  else
                    for (var index = 0; index < bands.length; index++) ...[
                      _BandCard(
                        band: bands[index],
                        onTap: () => _openBand(bands[index]),
                      ),
                      if (index < bands.length - 1) const SizedBox(height: 14),
                    ],
                ],
              );
            }

            if (snapshot.hasError) {
              return _BandsLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _BandCard extends StatelessWidget {
  const _BandCard({required this.band, required this.onTap});

  final Band band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel(band);
    final resolvedPhotoUrl = ApiConfig.publicFileUrl(band.photoUrl);

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
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: MusiHubColors.fieldGrey,
                backgroundImage: resolvedPhotoUrl.isEmpty
                    ? null
                    : NetworkImage(resolvedPhotoUrl),
                child: resolvedPhotoUrl.isEmpty
                    ? const Icon(Icons.groups_outlined, color: Colors.black54)
                    : null,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      band.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    if (location != null)
                      Text(
                        location,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _SmallBadge(label: '${band.members.length} miembros'),
                        for (final style in band.styles.take(2))
                          _SmallBadge(label: style.name),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }

  String? _locationLabel(Band band) {
    final parts = [
      band.city,
      band.province,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final label = parts.join(', ');

    return label.isEmpty ? null : label;
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(
          color: MusiHubColors.primary.withValues(alpha: 0.55),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _EmptyBands extends StatelessWidget {
  const _EmptyBands({required this.onCreateBand});

  final VoidCallback onCreateBand;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.groups_outlined, color: MusiHubColors.textGrey),
          const SizedBox(height: 8),
          Text(
            'Todavía no perteneces a ninguna banda.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onCreateBand,
            child: const Text('Crear banda'),
          ),
        ],
      ),
    );
  }
}

class _BandsLoadError extends StatelessWidget {
  const _BandsLoadError({required this.onRetry});

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
              'No se pudieron cargar tus bandas.',
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
