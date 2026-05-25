import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/bands/band_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/public_profile_screen.dart';
import 'package:musihub_front/features/search/search_api.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _queryController = TextEditingController();
  final _apiClient = ApiClient();

  late final AuthApi _authApi;
  late final OpportunitiesApi _opportunitiesApi;
  late final SearchApi _searchApi;

  Future<_SearchResults>? _resultsFuture;
  String _submittedQuery = '';

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _searchApi = SearchApi(apiClient: _apiClient);
  }

  @override
  void dispose() {
    _queryController.dispose();
    _apiClient.close();
    super.dispose();
  }

  void _submitSearch() {
    final query = _queryController.text.trim();

    setState(() {
      _submittedQuery = query;
      _resultsFuture = query.isEmpty ? null : _loadResults(query);
    });
  }

  Future<_SearchResults> _loadResults(String query) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    final opportunitiesFuture = _opportunitiesApi.listOpportunities(
      filters: OpportunityFilters(query: query),
    );
    final profilesFuture = _searchApi.searchProfiles(
      token: token,
      query: query,
    );
    final bandsFuture = _searchApi.searchBands(token: token, query: query);
    final userFuture = _authApi.me(token);

    final opportunities = await opportunitiesFuture;
    final profiles = await profilesFuture;
    final bands = await bandsFuture;
    final user = await userFuture;

    return _SearchResults(
      opportunities: opportunities
          .where((opportunity) => opportunity.authorUserId != user.id)
          .toList(),
      profiles: profiles
          .where((profile) => profile.user.id != user.id)
          .toList(),
      bands: bands,
    );
  }

  Future<void> _openOpportunity(Opportunity opportunity) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpportunityDetailScreen(
          opportunityId: opportunity.id,
          initialOpportunity: opportunity,
          tokenStore: widget.tokenStore,
        ),
      ),
    );
  }

  Future<void> _openProfile(ProfileSearchResult profile) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          tokenStore: widget.tokenStore,
          userId: profile.user.id,
        ),
      ),
    );
  }

  Future<void> _openBand(BandSearchResult band) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            BandDetailScreen(tokenStore: widget.tokenStore, bandId: band.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(title: const Text('Buscar')),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 14),
                child: _SearchInput(
                  controller: _queryController,
                  onSubmitted: _submitSearch,
                ),
              ),
              const TabBar(
                tabs: [
                  Tab(text: 'Anuncios'),
                  Tab(text: 'Perfiles'),
                  Tab(text: 'Bandas'),
                ],
              ),
              Expanded(child: _buildResults()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResults() {
    final resultsFuture = _resultsFuture;

    if (_submittedQuery.isEmpty || resultsFuture == null) {
      return const _SearchInitialState();
    }

    return FutureBuilder<_SearchResults>(
      future: resultsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final results = snapshot.data!;

          return TabBarView(
            children: [
              _OpportunityResultsTab(
                opportunities: results.opportunities,
                onOpen: _openOpportunity,
              ),
              _ProfileResultsTab(
                profiles: results.profiles,
                onOpen: _openProfile,
              ),
              _BandResultsTab(bands: results.bands, onOpen: _openBand),
            ],
          );
        }

        if (snapshot.hasError) {
          return _SearchLoadError(onRetry: _submitSearch);
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }
}

class _SearchResults {
  const _SearchResults({
    required this.opportunities,
    required this.profiles,
    required this.bands,
  });

  final List<Opportunity> opportunities;
  final List<ProfileSearchResult> profiles;
  final List<BandSearchResult> bands;
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller, required this.onSubmitted});

  final TextEditingController controller;
  final VoidCallback onSubmitted;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      maxLength: InputLimits.shortText,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => onSubmitted(),
      decoration: InputDecoration(
        hintText: 'Buscar en MusiHub...',
        counterText: '',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          onPressed: onSubmitted,
          icon: const Icon(Icons.arrow_forward),
          tooltip: 'Buscar',
        ),
      ),
    );
  }
}

class _OpportunityResultsTab extends StatelessWidget {
  const _OpportunityResultsTab({
    required this.opportunities,
    required this.onOpen,
  });

  final List<Opportunity> opportunities;
  final ValueChanged<Opportunity> onOpen;

  @override
  Widget build(BuildContext context) {
    if (opportunities.isEmpty) {
      return const _EmptySearchTab(
        message: 'No hay anuncios para esta busqueda.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      itemCount: opportunities.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final opportunity = opportunities[index];
        return _OpportunitySearchCard(
          opportunity: opportunity,
          onTap: () => onOpen(opportunity),
        );
      },
    );
  }
}

class _ProfileResultsTab extends StatelessWidget {
  const _ProfileResultsTab({required this.profiles, required this.onOpen});

  final List<ProfileSearchResult> profiles;
  final ValueChanged<ProfileSearchResult> onOpen;

  @override
  Widget build(BuildContext context) {
    if (profiles.isEmpty) {
      return const _EmptySearchTab(
        message: 'No hay perfiles para esta busqueda.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      itemCount: profiles.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        return _ProfileSearchCard(
          profile: profile,
          onTap: () => onOpen(profile),
        );
      },
    );
  }
}

class _BandResultsTab extends StatelessWidget {
  const _BandResultsTab({required this.bands, required this.onOpen});

  final List<BandSearchResult> bands;
  final ValueChanged<BandSearchResult> onOpen;

  @override
  Widget build(BuildContext context) {
    if (bands.isEmpty) {
      return const _EmptySearchTab(
        message: 'No hay bandas para esta busqueda.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
      itemCount: bands.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final band = bands[index];
        return _BandSearchCard(band: band, onTap: () => onOpen(band));
      },
    );
  }
}

class _OpportunitySearchCard extends StatelessWidget {
  const _OpportunitySearchCard({
    required this.opportunity,
    required this.onTap,
  });

  final Opportunity opportunity;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final author =
        opportunity.authorBand?.name ?? opportunity.authorUser?.fullName;

    return _SearchCard(
      onTap: onTap,
      icon: Icons.campaign_outlined,
      title: opportunity.title,
      subtitle: opportunity.description,
      meta: [
        opportunityTypeFilterLabel(opportunity.type),
        opportunity.city,
        ?author,
      ],
    );
  }
}

class _ProfileSearchCard extends StatelessWidget {
  const _ProfileSearchCard({required this.profile, required this.onTap});

  final ProfileSearchResult profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SearchCard(
      onTap: onTap,
      photoUrl: profile.photoUrl,
      icon: Icons.person_outline,
      title: profile.user.fullName,
      subtitle: profile.bio ?? 'Perfil musical',
      meta: [
        if (_locationText(profile.city, profile.province) != null)
          _locationText(profile.city, profile.province)!,
        ...profile.instruments.take(2).map((instrument) => instrument.name),
        ...profile.styles.take(2).map((style) => style.name),
      ],
    );
  }
}

class _BandSearchCard extends StatelessWidget {
  const _BandSearchCard({required this.band, required this.onTap});

  final BandSearchResult band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return _SearchCard(
      onTap: onTap,
      photoUrl: band.photoUrl,
      icon: Icons.groups_outlined,
      title: band.name,
      subtitle: band.bio ?? 'Banda',
      meta: [
        if (_locationText(band.city, band.province) != null)
          _locationText(band.city, band.province)!,
        ...band.styles.take(3).map((style) => style.name),
      ],
    );
  }
}

class _SearchCard extends StatelessWidget {
  const _SearchCard({
    required this.onTap,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.meta,
    this.photoUrl,
  });

  final VoidCallback onTap;
  final IconData icon;
  final String title;
  final String subtitle;
  final List<String> meta;
  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: MusiHubColors.fieldGrey,
                backgroundImage: photoUrl == null
                    ? null
                    : NetworkImage(photoUrl!),
                child: photoUrl == null
                    ? Icon(icon, color: MusiHubColors.primary)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (meta.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: meta
                            .map((item) => _SearchTag(label: item))
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: MusiHubColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchTag extends StatelessWidget {
  const _SearchTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(label, style: Theme.of(context).textTheme.titleSmall),
    );
  }
}

class _SearchInitialState extends StatelessWidget {
  const _SearchInitialState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'Busca anuncios, perfiles y bandas por nombre, ciudad, instrumento o estilo.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _EmptySearchTab extends StatelessWidget {
  const _EmptySearchTab({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}

class _SearchLoadError extends StatelessWidget {
  const _SearchLoadError({required this.onRetry});

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
              'No se pudo completar la busqueda.',
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

String? _locationText(String? city, String? province) {
  final parts = [
    city?.trim(),
    province?.trim(),
  ].whereType<String>().where((part) => part.isNotEmpty).toList();

  return parts.isEmpty ? null : parts.join(', ');
}
