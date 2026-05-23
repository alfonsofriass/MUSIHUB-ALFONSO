import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/alerts/alerts_screen.dart';
import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/bands/my_bands_screen.dart';
import 'package:musihub_front/features/opportunities/favorite_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/my_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _bioController = TextEditingController();
  final _photoUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _apiClient = ApiClient();
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};

  late final ProfileApi _profileApi;
  late final BandsApi _bandsApi;
  late Future<_ProfileInitialData> _initialData;

  String? _token;
  int? _primaryInstrumentId;
  bool _profileExists = false;
  bool _isEditingProfile = false;
  bool _isSaving = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _profileApi = ProfileApi(apiClient: _apiClient);
    _bandsApi = BandsApi(apiClient: _apiClient);
    _initialData = _loadInitialData();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _provinceController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    _contactEmailController.dispose();
    _contactPhoneController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<_ProfileInitialData> _loadInitialData() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final profileFuture = _profileApi.getMyProfile(token);
    final bandsFuture = _bandsApi.listMyBands(token);

    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final profileMe = await profileFuture;
    final bands = await bandsFuture;

    _applyProfile(profileMe.profile);
    _profileExists = profileMe.exists;

    return _ProfileInitialData(
      instruments: instruments,
      styles: styles,
      bands: bands,
    );
  }

  void _applyProfile(UserProfile? profile) {
    _cityController.text = profile?.city ?? '';
    _provinceController.text = profile?.province ?? '';
    _bioController.text = profile?.bio ?? '';
    _photoUrlController.text = profile?.photoUrl ?? '';
    _contactEmailController.text = profile?.contactEmail ?? '';
    _contactPhoneController.text = profile?.contactPhone ?? '';

    _selectedInstrumentIds
      ..clear()
      ..addAll(profile?.instruments.map((instrument) => instrument.id) ?? []);
    _selectedStyleIds
      ..clear()
      ..addAll(profile?.styles.map((style) => style.id) ?? []);

    int? primaryInstrumentId;
    for (final instrument in profile?.instruments ?? <ProfileInstrument>[]) {
      if (instrument.isPrimary) {
        primaryInstrumentId = instrument.id;
        break;
      }
    }
    _primaryInstrumentId = primaryInstrumentId;
  }

  Future<void> _saveProfile() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
        _successMessage = null;
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      final savedProfile = await _profileApi.saveMyProfile(
        token: token,
        request: ProfileSaveRequest(
          city: _textOrNull(_cityController.text),
          province: _textOrNull(_provinceController.text),
          bio: _textOrNull(_bioController.text),
          photoUrl: _textOrNull(_photoUrlController.text),
          contactEmail: _textOrNull(_contactEmailController.text),
          contactPhone: _textOrNull(_contactPhoneController.text),
          instrumentIds: _selectedInstrumentIds.toList(),
          primaryInstrumentId:
              _selectedInstrumentIds.contains(_primaryInstrumentId)
              ? _primaryInstrumentId
              : null,
          styleIds: _selectedStyleIds.toList(),
        ),
      );

      if (!mounted) return;

      setState(() {
        _applyProfile(savedProfile.profile);
        _profileExists = savedProfile.exists;
        _isEditingProfile = false;
        _successMessage = 'Perfil guardado.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo guardar el perfil. Revisa los datos.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _retryLoad() {
    setState(() {
      _errorMessage = null;
      _successMessage = null;
      _isEditingProfile = false;
      _initialData = _loadInitialData();
    });
  }

  void _startEditing() {
    setState(() {
      _isEditingProfile = true;
      _errorMessage = null;
      _successMessage = null;
    });
  }

  void _cancelEditing() {
    setState(() {
      _isEditingProfile = false;
      _errorMessage = null;
      _successMessage = null;
      _initialData = _loadInitialData();
    });
  }

  Future<void> _openMyOpportunities() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MyOpportunitiesScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _openCreateOpportunity() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => OpportunityFormScreen(tokenStore: widget.tokenStore),
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
  }

  void _goHome() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openMyBands() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MyBandsScreen(tokenStore: widget.tokenStore),
      ),
    );

    if (!mounted) return;

    _retryLoad();
  }

  Future<void> _openMyAlerts() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AlertsScreen(
          tokenStore: widget.tokenStore,
          mode: AlertsScreenMode.generated,
        ),
      ),
    );
  }

  Future<void> _openAlertSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AlertsScreen(
          tokenStore: widget.tokenStore,
          mode: AlertsScreenMode.settings,
        ),
      ),
    );
  }

  Future<void> _logout() async {
    await widget.tokenStore.clearAccessToken();

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  Future<void> _showProfileSettings() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Ajustes', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                _ProfileSettingsAction(
                  icon: Icons.edit_outlined,
                  title: 'Editar perfil',
                  subtitle: 'Actualiza tu informacion musical',
                  onTap: () {
                    Navigator.of(context).pop();
                    _startEditing();
                  },
                ),
                _ProfileSettingsAction(
                  icon: Icons.notifications_outlined,
                  title: 'Configurar alertas',
                  subtitle: 'Ajusta tipos, frecuencia y ubicacion',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openAlertSettings();
                  },
                ),
                _ProfileSettingsAction(
                  icon: Icons.logout,
                  title: 'Cerrar sesion',
                  subtitle: 'Salir de esta cuenta',
                  danger: true,
                  onTap: () {
                    Navigator.of(context).pop();
                    _logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          if (!_isEditingProfile)
            IconButton(
              onPressed: _showProfileSettings,
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Ajustes',
            ),
        ],
      ),
      body: SafeArea(
        child: FutureBuilder<_ProfileInitialData>(
          future: _initialData,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _isEditingProfile
                  ? _buildForm(context, snapshot.data!)
                  : _buildProfileView(context, snapshot.data!);
            }

            if (snapshot.hasError) {
              return _buildLoadError();
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
      bottomNavigationBar: _isEditingProfile
          ? null
          : OpportunityFeedBottomNav(
              selectedIndex: 3,
              onHome: _goHome,
              onPublish: _openCreateOpportunity,
              onSaved: _openFavorites,
              onProfile: () {},
            ),
    );
  }

  Widget _buildProfileView(BuildContext context, _ProfileInitialData data) {
    final primaryInstrument = _selectedCatalogName(
      data.instruments,
      _primaryInstrumentId,
    );
    final location = _locationText();
    final headline = _summaryHeadline(primaryInstrument, location);
    final bio = _textOrNull(_bioController.text);
    final photoUrl = _textOrNull(_photoUrlController.text);
    final contactEmail = _textOrNull(_contactEmailController.text);
    final contactPhone = _textOrNull(_contactPhoneController.text);
    final selectedInstruments = _selectedCatalogNames(
      data.instruments,
      _selectedInstrumentIds,
      markPrimary: true,
    );
    final selectedStyles = _selectedCatalogNames(
      data.styles,
      _selectedStyleIds,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 96),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ProfileAvatar(photoUrl: photoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Perfil musical',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 4),
                  Text(headline, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!_profileExists)
          _ProfileEmptyState(onCreate: _startEditing)
        else ...[
          if (bio != null) _ProfileSection(title: 'Bio', children: [Text(bio)]),
          _ProfileSection(
            title: 'Mis bandas',
            children: [
              if (data.bands.isEmpty)
                const Text('Todavia no perteneces a ninguna banda.')
              else
                for (final band in data.bands.take(3)) ...[
                  _ProfileBandTile(band: band, onTap: _openMyBands),
                  const SizedBox(height: 8),
                ],
              OutlinedButton(
                onPressed: _openMyBands,
                child: const Text('Ver mis bandas'),
              ),
            ],
          ),
          _ProfileSection(
            title: 'Musica',
            children: [
              if (selectedInstruments.isNotEmpty) ...[
                Text(
                  'Instrumentos',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _ChipWrap(items: selectedInstruments),
              ],
              if (selectedStyles.isNotEmpty) ...[
                if (selectedInstruments.isNotEmpty) const SizedBox(height: 16),
                Text('Estilos', style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                _ChipWrap(items: selectedStyles),
              ],
              if (selectedInstruments.isEmpty && selectedStyles.isEmpty)
                const Text('Sin instrumentos ni estilos indicados.'),
            ],
          ),
          _ProfileSection(
            title: 'Contacto',
            children: [
              if (contactEmail != null)
                _InfoRow(icon: Icons.mail_outline, text: contactEmail),
              if (contactPhone != null) ...[
                if (contactEmail != null) const SizedBox(height: 8),
                _InfoRow(icon: Icons.phone_outlined, text: contactPhone),
              ],
              if (contactEmail == null && contactPhone == null)
                const Text('Sin datos de contacto visibles.'),
            ],
          ),
        ],
        _ProfileSection(
          title: 'Mi actividad',
          children: [
            _ActivityActionTile(
              icon: Icons.campaign_outlined,
              title: 'Mis anuncios',
              subtitle: 'Edita, revisa o cierra tus publicaciones',
              onTap: _openMyOpportunities,
            ),
            const SizedBox(height: 10),
            _ActivityActionTile(
              icon: Icons.notifications_outlined,
              title: 'Mis alertas',
              subtitle: 'Consulta oportunidades recomendadas para ti',
              onTap: _openMyAlerts,
            ),
          ],
        ),
        if (!_profileExists) ...[
          _ActivityActionTile(
            icon: Icons.groups_outlined,
            title: 'Mis bandas',
            subtitle: 'Crea o gestiona tus proyectos musicales',
            onTap: _openMyBands,
          ),
          const SizedBox(height: 24),
        ],
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _successMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildLoadError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No se pudo cargar el perfil.'),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _retryLoad,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context, _ProfileInitialData data) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCurrentSummary(context, data),
        const SizedBox(height: 16),
        _ProfileSection(
          title: 'Datos basicos',
          children: [
            TextField(
              controller: _cityController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Ciudad'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _provinceController,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Provincia'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              onChanged: (_) => setState(() {}),
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
        _ProfileSection(
          title: 'Contacto',
          children: [
            TextField(
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email de contacto'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Telefono de contacto',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _photoUrlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(labelText: 'URL de foto'),
            ),
          ],
        ),
        _ProfileSection(
          title: 'Instrumentos',
          children: [
            _buildInstrumentChips(data.instruments),
            const SizedBox(height: 16),
            _buildPrimaryInstrumentSelect(data.instruments),
            const SizedBox(height: 8),
            _buildClearSelectionButton(),
          ],
        ),
        _ProfileSection(
          title: 'Estilos',
          children: [_buildStyleChips(data.styles)],
        ),
        FilledButton(
          onPressed: _isSaving ? null : () => _saveProfile(),
          child: Text(_isSaving ? 'Guardando...' : 'Guardar perfil'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: _isSaving ? null : _cancelEditing,
          child: const Text('Cancelar edicion'),
        ),
        if (_successMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _successMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.primary),
          ),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
      ],
    );
  }

  Widget _buildCurrentSummary(BuildContext context, _ProfileInitialData data) {
    final primaryInstrument = _selectedCatalogName(
      data.instruments,
      _primaryInstrumentId,
    );
    final location = _locationText();
    final headline = _summaryHeadline(primaryInstrument, location);
    final bio = _textOrNull(_bioController.text);
    final selectedInstruments = _selectedCatalogNames(
      data.instruments,
      _selectedInstrumentIds,
      markPrimary: true,
    );
    final selectedStyles = _selectedCatalogNames(
      data.styles,
      _selectedStyleIds,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _profileExists ? 'Editar perfil' : 'Crear perfil',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(headline),
        if (bio != null) ...[const SizedBox(height: 8), Text(bio)],
        if (selectedInstruments.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChipWrap(items: selectedInstruments),
        ],
        if (selectedStyles.isNotEmpty) ...[
          const SizedBox(height: 12),
          _ChipWrap(items: selectedStyles),
        ],
      ],
    );
  }

  Widget _buildInstrumentChips(List<CatalogItem> instruments) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: instruments.map((instrument) {
        final isSelected = _selectedInstrumentIds.contains(instrument.id);

        return FilterChip(
          label: Text(instrument.name),
          selected: isSelected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedInstrumentIds.add(instrument.id);
                _primaryInstrumentId ??= instrument.id;
              } else {
                _selectedInstrumentIds.remove(instrument.id);
                if (_primaryInstrumentId == instrument.id) {
                  _primaryInstrumentId = _selectedInstrumentIds.isEmpty
                      ? null
                      : _selectedInstrumentIds.first;
                }
              }
            });
          },
        );
      }).toList(),
    );
  }

  Widget _buildStyleChips(List<CatalogItem> styles) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: styles.map((style) {
        return FilterChip(
          label: Text(style.name),
          selected: _selectedStyleIds.contains(style.id),
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedStyleIds.add(style.id);
              } else {
                _selectedStyleIds.remove(style.id);
              }
            });
          },
        );
      }).toList(),
    );
  }

  String _summaryHeadline(String? primaryInstrument, String? location) {
    if (primaryInstrument != null && location != null) {
      return '$primaryInstrument en $location';
    }

    if (primaryInstrument != null) {
      return primaryInstrument;
    }

    if (location != null) {
      return location;
    }

    return 'Perfil musical pendiente de completar.';
  }

  String? _locationText() {
    final parts = [
      _textOrNull(_cityController.text),
      _textOrNull(_provinceController.text),
    ].whereType<String>().toList();

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }

  String? _selectedCatalogName(List<CatalogItem> items, int? selectedId) {
    for (final item in items) {
      if (item.id == selectedId) {
        return item.name;
      }
    }

    return null;
  }

  List<String> _selectedCatalogNames(
    List<CatalogItem> items,
    Set<int> ids, {
    bool markPrimary = false,
  }) {
    return items.where((item) => ids.contains(item.id)).map((item) {
      if (markPrimary && item.id == _primaryInstrumentId) {
        return '${item.name} principal';
      }

      return item.name;
    }).toList();
  }

  void _clearMusicalSelection() {
    setState(() {
      _selectedInstrumentIds.clear();
      _primaryInstrumentId = null;
      _selectedStyleIds.clear();
    });
  }

  Widget _buildClearSelectionButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: _clearMusicalSelection,
        child: const Text('Limpiar instrumentos y estilos'),
      ),
    );
  }

  Widget _buildPrimaryInstrumentSelect(List<CatalogItem> instruments) {
    final selectedInstruments = instruments
        .where((instrument) => _selectedInstrumentIds.contains(instrument.id))
        .toList();
    final selectedPrimary =
        _selectedInstrumentIds.contains(_primaryInstrumentId)
        ? _primaryInstrumentId
        : null;

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Instrumento principal'),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          isExpanded: true,
          value: selectedPrimary,
          hint: const Text('Sin instrumento principal'),
          items: selectedInstruments
              .map(
                (instrument) => DropdownMenuItem<int>(
                  value: instrument.id,
                  child: Text(instrument.name),
                ),
              )
              .toList(),
          onChanged: selectedInstruments.isEmpty
              ? null
              : (value) {
                  setState(() {
                    _primaryInstrumentId = value;
                  });
                },
        ),
      ),
    );
  }
}

class _ProfileAvatar extends StatelessWidget {
  const _ProfileAvatar({required this.photoUrl});

  final String? photoUrl;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 38,
      backgroundColor: MusiHubColors.fieldGrey,
      backgroundImage: photoUrl == null ? null : NetworkImage(photoUrl!),
      child: photoUrl == null
          ? const Icon(Icons.person_outline, size: 38, color: Colors.black54)
          : null,
    );
  }
}

class _ProfileEmptyState extends StatelessWidget {
  const _ProfileEmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Perfil pendiente',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          const Text(
            'Completa tu perfil para mostrar instrumentos, estilos y contacto.',
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCreate, child: const Text('Crear perfil')),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: MusiHubColors.textGrey),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}

class _ActivityActionTile extends StatelessWidget {
  const _ActivityActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: MusiHubColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: MusiHubColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: MusiHubColors.textGrey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileSettingsAction extends StatelessWidget {
  const _ProfileSettingsAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? Colors.redAccent : MusiHubColors.primary;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(icon, color: color),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }
}

class _ProfileBandTile extends StatelessWidget {
  const _ProfileBandTile({required this.band, required this.onTap});

  final Band band;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final location = _locationLabel();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: MusiHubColors.primary.withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 13,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.groups_outlined,
                size: 16,
                color: MusiHubColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    band.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (location != null)
                    Text(
                      location,
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
      ),
    );
  }

  String? _locationLabel() {
    final parts = [
      band.city,
      band.province,
    ].where((part) => part != null && part.trim().isNotEmpty).cast<String>();
    final label = parts.join(', ');

    return label.isEmpty ? null : label;
  }
}

class _ProfileSection extends StatelessWidget {
  const _ProfileSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...children,
          const SizedBox(height: 8),
          const Divider(),
        ],
      ),
    );
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
      children: items
          .map(
            (item) => Chip(
              label: Text(item),
              backgroundColor: MusiHubColors.primary.withValues(alpha: 0.75),
              labelStyle: const TextStyle(color: Colors.white),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ProfileInitialData {
  const _ProfileInitialData({
    required this.instruments,
    required this.styles,
    required this.bands,
  });

  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<Band> bands;
}
