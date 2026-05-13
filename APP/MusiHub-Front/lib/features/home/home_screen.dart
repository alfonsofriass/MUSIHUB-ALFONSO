import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/opportunities/my_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_list_screen.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/profile/profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.user, required this.tokenStore});

  final AuthUser user;
  final TokenStore tokenStore;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _apiClient = ApiClient();

  late final ProfileApi _profileApi;
  late Future<ProfileMe> _profileFuture;

  @override
  void initState() {
    super.initState();
    _profileApi = ProfileApi(apiClient: _apiClient);
    _profileFuture = _loadProfile();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<ProfileMe> _loadProfile() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    return _profileApi.getMyProfile(token);
  }

  void _refreshProfile() {
    setState(() {
      _profileFuture = _loadProfile();
    });
  }

  Future<void> _logout(BuildContext context) async {
    await widget.tokenStore.clearAccessToken();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
    );
  }

  Future<void> _openProfile(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => ProfileScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (!mounted) return;

    _refreshProfile();
  }

  Future<void> _openOpportunities(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const OpportunitiesListScreen()),
    );
  }

  Future<void> _openMyOpportunities(BuildContext context) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MyOpportunitiesScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _openCreateOpportunity(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MusiHub'),
        actions: [
          IconButton(
            onPressed: _refreshProfile,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar perfil',
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Sesion iniciada',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text('Nombre: ${widget.user.fullName}'),
            Text('Email: ${widget.user.email}'),
            Text('Rol: ${widget.user.role}'),
            const SizedBox(height: 24),
            FutureBuilder<ProfileMe>(
              future: _profileFuture,
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  return _ProfileSummary(
                    profileMe: snapshot.data!,
                    onEdit: () => _openProfile(context),
                  );
                }

                if (snapshot.hasError) {
                  return _ProfileLoadError(onRetry: _refreshProfile);
                }

                return const _ProfileLoading();
              },
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => _openOpportunities(context),
              child: const Text('Ver anuncios'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _openMyOpportunities(context),
              child: const Text('Mis anuncios'),
            ),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => _openCreateOpportunity(context),
              child: const Text('Crear anuncio'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () => _logout(context),
              child: const Text('Cerrar sesion'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Cargando perfil...'),
      ],
    );
  }
}

class _ProfileLoadError extends StatelessWidget {
  const _ProfileLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No se pudo cargar el perfil.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class _ProfileSummary extends StatelessWidget {
  const _ProfileSummary({required this.profileMe, required this.onEdit});

  final ProfileMe profileMe;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = profileMe.profile;

    if (!profileMe.exists || profile == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Perfil musical', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          const Text('Pendiente de crear.'),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: onEdit,
            child: const Text('Crear perfil musical'),
          ),
        ],
      );
    }

    final primaryInstrument = _primaryInstrumentName(profile);
    final location = _locationText(profile);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Perfil musical', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(_headline(primaryInstrument, location)),
        const SizedBox(height: 8),
        if (profile.bio != null && profile.bio!.isNotEmpty) Text(profile.bio!),
        if (profile.instruments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChipWrap(
            items: profile.instruments
                .map(
                  (instrument) => instrument.isPrimary
                      ? '${instrument.name} principal'
                      : instrument.name,
                )
                .toList(),
          ),
        ],
        if (profile.styles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChipWrap(items: profile.styles.map((style) => style.name).toList()),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onEdit,
          child: const Text('Ver o editar perfil'),
        ),
      ],
    );
  }

  String _headline(String? primaryInstrument, String? location) {
    if (primaryInstrument != null && location != null) {
      return '$primaryInstrument en $location';
    }

    if (primaryInstrument != null) {
      return primaryInstrument;
    }

    if (location != null) {
      return location;
    }

    return 'Perfil creado';
  }

  String? _primaryInstrumentName(UserProfile profile) {
    for (final instrument in profile.instruments) {
      if (instrument.isPrimary) {
        return instrument.name;
      }
    }

    if (profile.instruments.isEmpty) {
      return null;
    }

    return profile.instruments.first.name;
  }

  String? _locationText(UserProfile profile) {
    final parts = [
      profile.city,
      profile.province,
    ].where((part) => part != null && part.isNotEmpty).cast<String>().toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }
}

class _ChipWrap extends StatelessWidget {
  const _ChipWrap({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((item) => Chip(label: Text(item))).toList(),
    );
  }
}
