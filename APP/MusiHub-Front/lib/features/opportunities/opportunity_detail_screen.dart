import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/opportunities/favorite_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';

class OpportunityDetailScreen extends StatefulWidget {
  const OpportunityDetailScreen({
    super.key,
    required this.opportunityId,
    required this.tokenStore,
    this.initialOpportunity,
  });

  final int opportunityId;
  final TokenStore tokenStore;
  final Opportunity? initialOpportunity;

  @override
  State<OpportunityDetailScreen> createState() =>
      _OpportunityDetailScreenState();
}

class _OpportunityDetailScreenState extends State<OpportunityDetailScreen> {
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late Future<_OpportunityDetailData> _detailFuture;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _detailFuture = _loadDetailData();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<_OpportunityDetailData> _loadDetailData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    final opportunityFuture = widget.initialOpportunity == null
        ? _opportunitiesApi.getOpportunity(widget.opportunityId)
        : Future.value(widget.initialOpportunity!);
    final favoritesFuture = _opportunitiesApi.listFavoriteOpportunities(token);

    final opportunity = await opportunityFuture;
    final favorites = await favoritesFuture;

    return _OpportunityDetailData(
      opportunity: opportunity,
      isFavorite: favorites.any((favorite) => favorite.id == opportunity.id),
    );
  }

  void _refresh() {
    setState(() {
      _detailFuture = _loadDetailData();
    });
  }

  Future<void> _openCreateOpportunity() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
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

  Future<void> _toggleFavorite(_OpportunityDetailData data) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      final favoriteStatus = data.isFavorite
          ? await _opportunitiesApi.removeFavorite(
              token: token,
              opportunityId: data.opportunity.id,
            )
          : await _opportunitiesApi.saveFavorite(
              token: token,
              opportunityId: data.opportunity.id,
            );

      if (!mounted) return;

      setState(() {
        _detailFuture = Future.value(
          data.copyWith(isFavorite: favoriteStatus.isFavorite),
        );
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo actualizar el favorito.')),
      );
    }
  }

  void _showFutureFeature(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label estara disponible mas adelante.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles Anuncio'),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: () => _showFutureFeature('Compartir'),
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Compartir',
          ),
          FutureBuilder<_OpportunityDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;

              return IconButton(
                onPressed: data == null ? null : () => _toggleFavorite(data),
                icon: Icon(
                  data != null && data.isFavorite
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: data != null && data.isFavorite
                      ? MusiHubColors.primary
                      : null,
                ),
                tooltip: data != null && data.isFavorite
                    ? 'Quitar de guardados'
                    : 'Guardar',
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_OpportunityDetailData>(
          future: _detailFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _OpportunityDetail(
                opportunity: snapshot.data!.opportunity,
                onContactTap: () => _showFutureFeature('Contacto'),
              );
            }

            if (snapshot.hasError) {
              return _OpportunityLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
      bottomNavigationBar: OpportunityFeedBottomNav(
        onHome: () => Navigator.of(context).pop(),
        onPublish: _openCreateOpportunity,
        onSaved: _openFavorites,
        onProfile: _openProfile,
      ),
    );
  }
}

class _OpportunityDetailData {
  const _OpportunityDetailData({
    required this.opportunity,
    required this.isFavorite,
  });

  final Opportunity opportunity;
  final bool isFavorite;

  _OpportunityDetailData copyWith({bool? isFavorite}) {
    return _OpportunityDetailData(
      opportunity: opportunity,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class _OpportunityDetail extends StatelessWidget {
  const _OpportunityDetail({
    required this.opportunity,
    required this.onContactTap,
  });

  final Opportunity opportunity;
  final VoidCallback onContactTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
      children: [
        _OpportunityTags(opportunity: opportunity),
        const SizedBox(height: 22),
        Text(
          opportunity.title,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 26),
        _OpportunityMeta(opportunity: opportunity),
        const SizedBox(height: 26),
        Text('Descripcion', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _DescriptionBox(description: opportunity.description),
        const SizedBox(height: 20),
        Text('Publicado por', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _AuthorTile(opportunity: opportunity),
        const SizedBox(height: 16),
        FilledButton(onPressed: onContactTap, child: const Text('Contactar')),
      ],
    );
  }
}

class _OpportunityTags extends StatelessWidget {
  const _OpportunityTags({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final tags = [
      _TagData(
        label: opportunityTypeTagLabel(opportunity.type),
        color: opportunityTypeTagColor(opportunity.type),
      ),
      if (opportunity.instruments.isNotEmpty)
        _TagData(label: opportunity.instruments.first.name),
      if (opportunity.styles.isNotEmpty)
        _TagData(label: opportunity.styles.first.name),
    ];

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: tags.map((tag) => _SmallTag(tag: tag)).toList(),
    );
  }
}

class _TagData {
  const _TagData({required this.label, this.color = MusiHubColors.fieldGrey});

  final String label;
  final Color color;
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.tag});

  final _TagData tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 74, maxWidth: 124),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: MusiHubColors.borderGrey),
      ),
      child: Text(
        tag.label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OpportunityMeta extends StatelessWidget {
  const _OpportunityMeta({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 34,
      runSpacing: 22,
      children: [
        _MetaBlock(
          icon: Icons.location_on_outlined,
          label: 'Localizacion',
          value: _locationLabel(opportunity),
        ),
        if (opportunity.eventDate != null)
          _MetaBlock(
            icon: Icons.calendar_month_outlined,
            label: 'Fecha',
            value: opportunityLongDateLabel(opportunity.eventDate!),
          ),
        if (opportunity.priceAmount != null)
          _MetaBlock(
            icon: Icons.euro,
            label: 'Precio',
            value: opportunityPriceLabel(opportunity.priceAmount!),
            accent: true,
          ),
      ],
    );
  }

  String _locationLabel(Opportunity opportunity) {
    final parts = [
      opportunity.city,
      opportunity.province,
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

    return parts.isEmpty ? 'Sin ubicacion' : parts.join(', ');
  }
}

class _MetaBlock extends StatelessWidget {
  const _MetaBlock({
    required this.icon,
    required this.label,
    required this.value,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ? MusiHubColors.primary : Colors.black;

    return SizedBox(
      width: 116,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 30,
            color: accent ? MusiHubColors.primary : MusiHubColors.textGrey,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DescriptionBox extends StatelessWidget {
  const _DescriptionBox({required this.description});

  final String description;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 136),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MusiHubColors.borderGrey),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        description,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: MusiHubColors.textGrey,
          height: 1.35,
        ),
      ),
    );
  }
}

class _AuthorTile extends StatelessWidget {
  const _AuthorTile({required this.opportunity});

  final Opportunity opportunity;

  @override
  Widget build(BuildContext context) {
    final authorBand = opportunity.authorBand;
    final authorLabel = authorBand == null
        ? 'Usuario #${opportunity.authorUserId}'
        : authorBand.name;
    final authorType = authorBand == null ? 'Perfil' : 'Banda';

    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFD0D0D0),
        border: Border.all(color: const Color(0xFF9A9A9A)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: Color(0xFF8F8F8F),
            child: Icon(Icons.group_outlined, size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  authorLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white),
                ),
                Text(
                  authorType,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: Colors.white),
        ],
      ),
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
