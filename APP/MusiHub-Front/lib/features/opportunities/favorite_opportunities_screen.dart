import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';

class FavoriteOpportunitiesScreen extends StatefulWidget {
  const FavoriteOpportunitiesScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<FavoriteOpportunitiesScreen> createState() =>
      _FavoriteOpportunitiesScreenState();
}

class _FavoriteOpportunitiesScreenState
    extends State<FavoriteOpportunitiesScreen> {
  final _apiClient = ApiClient();

  late final OpportunitiesApi _opportunitiesApi;
  late Future<List<Opportunity>> _favoritesFuture;

  @override
  void initState() {
    super.initState();
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _favoritesFuture = _loadFavorites();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<List<Opportunity>> _loadFavorites() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    return _opportunitiesApi.listFavoriteOpportunities(token);
  }

  void _refresh() {
    setState(() {
      _favoritesFuture = _loadFavorites();
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
  }

  Future<void> _openProfile() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _removeFavorite(Opportunity opportunity) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    try {
      await _opportunitiesApi.removeFavorite(
        token: token,
        opportunityId: opportunity.id,
      );

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo quitar el favorito.')),
      );
    }
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Guardados')),
      body: SafeArea(
        child: FutureBuilder<List<Opportunity>>(
          future: _favoritesFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final favorites = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 96),
                children: [
                  Text(
                    'Guardados',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Anuncios que quieres revisar o contactar más adelante.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  OpportunityFeedResults(
                    opportunities: favorites,
                    favoriteIds: favorites
                        .map((opportunity) => opportunity.id)
                        .toSet(),
                    hasFilters: false,
                    emptyMessage: 'Todavía no has guardado ningún anuncio.',
                    onOpen: _openDetail,
                    onFavoriteTap: _removeFavorite,
                  ),
                ],
              );
            }

            if (snapshot.hasError) {
              return OpportunitiesLoadError(
                message: 'No se pudieron cargar tus favoritos.',
                onRetry: _refresh,
              );
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
      bottomNavigationBar: OpportunityFeedBottomNav(
        selectedIndex: 2,
        onHome: _goHome,
        onPublish: _openCreateOpportunity,
        onSaved: () {},
        onProfile: _openProfile,
      ),
    );
  }
}
