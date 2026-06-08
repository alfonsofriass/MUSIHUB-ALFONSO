import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/push/push_notifications_service.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/contact_action_tile.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/features/alerts/alerts_screen.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/bands/bands_api.dart';
import 'package:musihub_front/features/bands/my_bands_screen.dart';
import 'package:musihub_front/features/contact_requests/contact_requests_screen.dart';
import 'package:musihub_front/features/opportunities/favorite_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/my_opportunities_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_form_screen.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_feed_widgets.dart';
import 'package:musihub_front/features/profile/profile_api.dart';
import 'package:musihub_front/features/profile/widgets/profile_widgets.dart';

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
  final _websiteUrlController = TextEditingController();
  final _contactEmailController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _apiClient = ApiClient();
  final _imagePicker = ImagePicker();
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};

  late final AuthApi _authApi;
  late final ProfileApi _profileApi;
  late final BandsApi _bandsApi;
  late final LocationsApi _locationsApi;
  late Future<_ProfileInitialData> _initialData;

  String? _token;
  int? _primaryInstrumentId;
  bool _profileExists = false;
  bool _isEditingProfile = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _bandsApi = BandsApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
    _initialData = _loadInitialData();
  }

  @override
  void dispose() {
    _cityController.dispose();
    _provinceController.dispose();
    _bioController.dispose();
    _photoUrlController.dispose();
    _websiteUrlController.dispose();
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

    final userFuture = _authApi.me(token);
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final profileFuture = _profileApi.getMyProfile(token);
    final bandsFuture = _bandsApi.listMyBands(token);
    final locationsFuture = _locationsApi.listLocations();

    final user = await userFuture;
    final instruments = await instrumentsFuture;
    final styles = await stylesFuture;
    final profileMe = await profileFuture;
    final bands = await bandsFuture;
    final locations = await locationsFuture;

    _applyProfile(profileMe.profile);
    _profileExists = profileMe.exists;

    return _ProfileInitialData(
      user: user,
      instruments: instruments,
      styles: styles,
      bands: bands,
      locations: locations,
    );
  }

  void _applyProfile(UserProfile? profile) {
    _cityController.text = profile?.city ?? '';
    _provinceController.text = profile?.province ?? '';
    _bioController.text = profile?.bio ?? '';
    _photoUrlController.text = profile?.photoUrl ?? '';
    _websiteUrlController.text = profile?.websiteUrl ?? '';
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
          websiteUrl: _textOrNull(_websiteUrlController.text),
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

  Future<void> _pickAndUploadProfilePhoto() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      setState(() {
        _errorMessage = 'No hay sesion activa.';
        _successMessage = null;
      });
      return;
    }

    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        imageQuality: 82,
      );

      if (image == null) {
        return;
      }

      setState(() {
        _isUploadingPhoto = true;
        _errorMessage = null;
        _successMessage = null;
      });

      final response = await _profileApi.uploadMyProfilePhoto(
        token: token,
        file: File(image.path),
      );

      if (!mounted) return;

      setState(() {
        _photoUrlController.text = response.photoUrl;
        _profileExists = true;
        _successMessage = 'Foto de perfil actualizada.';
      });
    } on UnsupportedProfilePhotoTypeException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'La foto debe ser JPG, PNG o WebP.';
      });
    } on ProfilePhotoTooLargeException {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'La foto no puede superar 5 MB.';
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo subir la foto.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _openMyOpportunities() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => MyOpportunitiesScreen(tokenStore: widget.tokenStore),
      ),
    );
  }

  Future<void> _openReceivedContactRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContactRequestsScreen(
          tokenStore: widget.tokenStore,
          mode: ContactRequestsScreenMode.received,
        ),
      ),
    );
  }

  Future<void> _openSentContactRequests() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ContactRequestsScreen(
          tokenStore: widget.tokenStore,
          mode: ContactRequestsScreenMode.sent,
        ),
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
    final token = _token ?? await widget.tokenStore.readAccessToken();

    if (token != null && token.isNotEmpty) {
      await PushNotificationsService.unregisterDevice(authToken: token);
    }

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
                ProfileSettingsAction(
                  icon: Icons.edit_outlined,
                  title: 'Editar perfil',
                  subtitle: 'Actualiza tu informacion musical',
                  onTap: () {
                    Navigator.of(context).pop();
                    _startEditing();
                  },
                ),
                ProfileSettingsAction(
                  icon: Icons.notifications_outlined,
                  title: 'Configurar alertas',
                  subtitle: 'Ajusta tipos, instrumentos, estilos y ubicacion',
                  onTap: () {
                    Navigator.of(context).pop();
                    _openAlertSettings();
                  },
                ),
                ProfileSettingsAction(
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
    final websiteUrl = _textOrNull(_websiteUrlController.text);
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
            ProfileAvatar(photoUrl: photoUrl),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.user.fullName,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  RoleBadge(role: data.user.role),
                  const SizedBox(height: 6),
                  Text(headline, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (!_profileExists)
          ProfileEmptyState(onCreate: _startEditing)
        else ...[
          if (bio != null)
            ProfileSection(
              title: 'Bio',
              icon: Icons.notes_outlined,
              children: [Text(bio)],
            ),
          ProfileSection(
            title: 'Mis bandas',
            icon: Icons.groups_outlined,
            children: [
              if (data.bands.isEmpty)
                const Text('Todavia no perteneces a ninguna banda.')
              else
                for (final band in data.bands.take(3)) ...[
                  ProfileBandTile(band: band, onTap: _openMyBands),
                  const SizedBox(height: 8),
                ],
              OutlinedButton(
                onPressed: _openMyBands,
                child: const Text('Ver mis bandas'),
              ),
            ],
          ),
          ProfileSection(
            title: 'Musica',
            icon: Icons.music_note_outlined,
            children: [
              if (selectedInstruments.isNotEmpty) ...[
                const MusicalInfoLabel(
                  icon: Icons.music_note_outlined,
                  label: 'Instrumentos',
                ),
                const SizedBox(height: 8),
                ChipWrap(items: selectedInstruments),
              ],
              if (selectedStyles.isNotEmpty) ...[
                if (selectedInstruments.isNotEmpty) const SizedBox(height: 16),
                const MusicalInfoLabel(
                  icon: Icons.library_music_outlined,
                  label: 'Estilos',
                ),
                const SizedBox(height: 8),
                ChipWrap(items: selectedStyles),
              ],
              if (selectedInstruments.isEmpty && selectedStyles.isEmpty)
                const Text('Sin instrumentos ni estilos indicados.'),
            ],
          ),
          ProfileSection(
            title: 'Contacto y enlaces',
            icon: Icons.link_outlined,
            children: [
              if (contactEmail != null)
                ContactActionTile(method: 'email', value: contactEmail),
              if (contactPhone != null) ...[
                if (contactEmail != null) const SizedBox(height: 8),
                ContactActionTile(method: 'phone', value: contactPhone),
              ],
              if (websiteUrl != null) ...[
                if (contactEmail != null || contactPhone != null)
                  const SizedBox(height: 8),
                ContactActionTile(method: 'website', value: websiteUrl),
              ],
              if (contactEmail == null &&
                  contactPhone == null &&
                  websiteUrl == null)
                const Text('Sin contacto ni enlaces visibles.'),
            ],
          ),
        ],
        ProfileSection(
          title: 'Mi actividad',
          icon: Icons.apps_outlined,
          children: [
            ActivityActionTile(
              icon: Icons.campaign_outlined,
              title: 'Mis anuncios',
              subtitle: 'Edita, revisa o cierra tus publicaciones',
              onTap: _openMyOpportunities,
            ),
            const SizedBox(height: 10),
            ActivityActionTile(
              icon: Icons.inbox_outlined,
              title: 'Solicitudes recibidas',
              subtitle: 'Acepta o rechaza solicitudes de tus anuncios',
              onTap: _openReceivedContactRequests,
            ),
            const SizedBox(height: 10),
            ActivityActionTile(
              icon: Icons.send_outlined,
              title: 'Solicitudes enviadas',
              subtitle: 'Consulta el estado y contactos aceptados',
              onTap: _openSentContactRequests,
            ),
            const SizedBox(height: 10),
            ActivityActionTile(
              icon: Icons.notifications_outlined,
              title: 'Mis alertas',
              subtitle: 'Consulta oportunidades recomendadas para ti',
              onTap: _openMyAlerts,
            ),
          ],
        ),
        if (!_profileExists) ...[
          ActivityActionTile(
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
    final photoUrl = _textOrNull(_photoUrlController.text);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _buildCurrentSummary(context, data),
        const SizedBox(height: 16),
        ProfileSection(
          title: 'Foto de perfil',
          icon: Icons.photo_camera_outlined,
          children: [
            ProfilePhotoEditor(
              photoUrl: photoUrl,
              isUploading: _isUploadingPhoto,
              onTap: _isUploadingPhoto ? null : _pickAndUploadProfilePhoto,
            ),
          ],
        ),
        ProfileSection(
          title: 'Datos basicos',
          icon: Icons.badge_outlined,
          children: [
            LocationSelector(
              locations: data.locations,
              provinceController: _provinceController,
              cityController: _cityController,
              requireProvince: false,
              requireCity: false,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _bioController,
              onChanged: (_) => setState(() {}),
              maxLength: InputLimits.profileBio,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Bio'),
            ),
          ],
        ),
        ProfileSection(
          title: 'Contacto y enlaces',
          icon: Icons.link_outlined,
          children: [
            TextField(
              controller: _contactEmailController,
              keyboardType: TextInputType.emailAddress,
              maxLength: InputLimits.email,
              decoration: const InputDecoration(
                labelText: 'Email de contacto',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contactPhoneController,
              keyboardType: TextInputType.phone,
              maxLength: InputLimits.phone,
              inputFormatters: InputLimits.phoneFormatters,
              decoration: const InputDecoration(
                labelText: 'Telefono de contacto',
                counterText: '',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _websiteUrlController,
              keyboardType: TextInputType.url,
              maxLength: InputLimits.url,
              decoration: const InputDecoration(
                labelText: 'Web o red social',
                hintText: 'instagram.com/usuario',
                counterText: '',
              ),
            ),
          ],
        ),
        ProfileSection(
          title: 'Instrumentos',
          icon: Icons.music_note_outlined,
          children: [
            _buildInstrumentChips(data.instruments),
            const SizedBox(height: 16),
            _buildPrimaryInstrumentSelect(data.instruments),
            const SizedBox(height: 8),
            _buildClearSelectionButton(),
          ],
        ),
        ProfileSection(
          title: 'Estilos',
          icon: Icons.library_music_outlined,
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
    final photoUrl = _textOrNull(_photoUrlController.text);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: MusiHubColors.borderGrey),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ProfileAvatar(photoUrl: photoUrl),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _profileExists ? 'Editar perfil' : 'Crear perfil',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 6),
                    RoleBadge(role: data.user.role),
                    const SizedBox(height: 6),
                    Text(
                      headline,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bio != null) ...[const SizedBox(height: 12), Text(bio)],
          if (selectedInstruments.isNotEmpty) ...[
            const SizedBox(height: 12),
            ChipWrap(items: selectedInstruments),
          ],
          if (selectedStyles.isNotEmpty) ...[
            const SizedBox(height: 12),
            ChipWrap(items: selectedStyles),
          ],
        ],
      ),
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

class _ProfileInitialData {
  const _ProfileInitialData({
    required this.user,
    required this.instruments,
    required this.styles,
    required this.bands,
    required this.locations,
  });

  final AuthUser user;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<Band> bands;
  final List<LocationProvince> locations;
}
