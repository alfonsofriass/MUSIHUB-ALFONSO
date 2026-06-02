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
import 'package:musihub_front/core/uploads/image_upload_rules.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/core/widgets/photo_picker_panel.dart';
import 'package:musihub_front/features/alerts/alerts_api.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/auth/widgets/auth_logo.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_list_screen.dart';
import 'package:musihub_front/features/profile/profile_api.dart';

part 'widgets/register_onboarding_widgets.dart';

enum _RegisterStep { account, role, profile, alerts, done }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _roles = [
    _RoleOption(
      code: 'musico',
      title: 'Musico',
      subtitle: 'Busco oportunidades para tocar o colaborar',
      icon: Icons.music_note_rounded,
    ),
    _RoleOption(
      code: 'venta',
      title: 'Venta',
      subtitle: 'Vendo instrumentos o servicios musicales',
      icon: Icons.storefront_outlined,
    ),
    _RoleOption(
      code: 'sala_bar',
      title: 'Sala/bar',
      subtitle: 'Ofrezco espacio para actuaciones',
      icon: Icons.local_bar_outlined,
    ),
    _RoleOption(
      code: 'academia_profesor',
      title: 'Academia/Profesor',
      subtitle: 'Ofrezco formacion musical',
      icon: Icons.school_outlined,
    ),
  ];

  static const _immediateFrequency = 'immediate';

  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _repeatPasswordController = TextEditingController();
  final _cityController = TextEditingController();
  final _provinceController = TextEditingController();
  final _bioController = TextEditingController();
  final _contactPhoneController = TextEditingController();
  final _apiClient = ApiClient();
  final _tokenStore = TokenStore();
  final _imagePicker = ImagePicker();
  final _selectedInstrumentIds = <int>{};
  final _selectedStyleIds = <int>{};
  final _selectedOpportunityTypeIds = <int>{};
  final _selectedAlertInstrumentIds = <int>{};
  final _selectedAlertStyleIds = <int>{};

  late final AuthApi _authApi;
  late final ProfileApi _profileApi;
  late final AlertsApi _alertsApi;
  late final OpportunitiesApi _opportunitiesApi;
  late final LocationsApi _locationsApi;
  late Future<_OnboardingCatalogs> _catalogsFuture;

  _RegisterStep _step = _RegisterStep.account;
  String _selectedRole = _roles.first.code;
  bool _notificationsEnabled = true;
  bool _isLoading = false;
  bool _catalogDefaultsApplied = false;
  bool _profileSaved = false;
  bool _profilePhotoUploaded = false;
  bool _alertsSaved = false;
  bool _privacyAccepted = false;
  int? _primaryInstrumentId;
  String? _authToken;
  String? _errorMessage;
  File? _selectedProfilePhotoFile;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _profileApi = ProfileApi(apiClient: _apiClient);
    _alertsApi = AlertsApi(apiClient: _apiClient);
    _opportunitiesApi = OpportunitiesApi(apiClient: _apiClient);
    _locationsApi = LocationsApi(apiClient: _apiClient);
    _catalogsFuture = _loadCatalogs();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _repeatPasswordController.dispose();
    _cityController.dispose();
    _provinceController.dispose();
    _bioController.dispose();
    _contactPhoneController.dispose();
    _apiClient.close();
    super.dispose();
  }

  Future<_OnboardingCatalogs> _loadCatalogs() async {
    final instrumentsFuture = _profileApi.listInstruments();
    final stylesFuture = _profileApi.listMusicStyles();
    final opportunityTypesFuture = _opportunitiesApi.listOpportunityTypes();
    final locationsFuture = _locationsApi.listLocations();

    final catalogs = _OnboardingCatalogs(
      instruments: await instrumentsFuture,
      styles: await stylesFuture,
      opportunityTypes: await opportunityTypesFuture,
      locations: await locationsFuture,
    );

    if (!_catalogDefaultsApplied) {
      _selectedOpportunityTypeIds.addAll(
        catalogs.opportunityTypes.map((type) => type.id),
      );
      _catalogDefaultsApplied = true;
    }

    return catalogs;
  }

  void _retryCatalogs() {
    setState(() {
      _errorMessage = null;
      _catalogDefaultsApplied = false;
      _selectedOpportunityTypeIds.clear();
      _catalogsFuture = _loadCatalogs();
    });
  }

  void _goBack() {
    if (_isLoading) return;

    if (_step == _RegisterStep.account) {
      Navigator.of(context).pop();
      return;
    }

    if (_step == _RegisterStep.done) {
      return;
    }

    setState(() {
      _errorMessage = null;
      _step = _previousStep(_step);
    });
  }

  void _goToLogin() {
    if (_isLoading) return;
    Navigator.of(context).pop();
  }

  Future<void> _continue({required _OnboardingCatalogs? catalogs}) async {
    FocusScope.of(context).unfocus();

    switch (_step) {
      case _RegisterStep.account:
        _validateAccountStep();
        if (_errorMessage != null) return;
        setState(() => _step = _RegisterStep.role);
      case _RegisterStep.role:
        setState(() {
          _errorMessage = null;
          _step = _RegisterStep.profile;
        });
      case _RegisterStep.profile:
        setState(() {
          _errorMessage = null;
          _step = _RegisterStep.alerts;
        });
      case _RegisterStep.alerts:
        if (catalogs == null) return;
        if (!_privacyAccepted) {
          setState(() {
            _errorMessage =
                'Acepta los terminos y la politica de privacidad para continuar.';
          });
          return;
        }
        await _finishOnboarding();
      case _RegisterStep.done:
        await _enterApp();
    }
  }

  void _validateAccountStep() {
    final fullName = _fullNameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final repeatedPassword = _repeatPasswordController.text;

    setState(() {
      if (fullName.isEmpty || email.isEmpty || password.isEmpty) {
        _errorMessage = 'Rellena nombre, email y contrasena.';
      } else if (password.length < 8) {
        _errorMessage = 'La contrasena debe tener al menos 8 caracteres.';
      } else if (password != repeatedPassword) {
        _errorMessage = 'Las contrasenas no coinciden.';
      } else {
        _errorMessage = null;
      }
    });
  }

  Future<void> _finishOnboarding() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _validateSelectedProfilePhoto();

      final token = await _ensureRegisteredAndLoggedIn();

      if (!_profileSaved) {
        await _profileApi.saveMyProfile(
          token: token,
          request: ProfileSaveRequest(
            city: _textOrNull(_cityController.text),
            province: _textOrNull(_provinceController.text),
            bio: _textOrNull(_bioController.text),
            photoUrl: null,
            websiteUrl: null,
            contactEmail: _textOrNull(_emailController.text),
            contactPhone: _textOrNull(_contactPhoneController.text),
            instrumentIds: _selectedInstrumentIds.toList(),
            primaryInstrumentId: _resolvedPrimaryInstrumentId(),
            styleIds: _selectedStyleIds.toList(),
          ),
        );

        if (_selectedProfilePhotoFile != null && !_profilePhotoUploaded) {
          await _uploadSelectedProfilePhoto(token);
          _profilePhotoUploaded = true;
        }

        _profileSaved = true;
      } else if (_selectedProfilePhotoFile != null && !_profilePhotoUploaded) {
        await _uploadSelectedProfilePhoto(token);
        _profilePhotoUploaded = true;
      }

      if (!_alertsSaved) {
        await _alertsApi.savePreferences(
          token: token,
          request: AlertPreferencesSaveRequest(
            frequency: _immediateFrequency,
            preferredCity: _textOrNull(_cityController.text),
            preferredProvince: _textOrNull(_provinceController.text),
            notificationsEnabled: _notificationsEnabled,
            opportunityTypeIds: _selectedOpportunityTypeIds.toList(),
            instrumentIds: _selectedAlertInstrumentIds.toList(),
            styleIds: _selectedAlertStyleIds.toList(),
          ),
        );
        _alertsSaved = true;
      }

      await _tokenStore.saveAccessToken(token);
      await PushNotificationsService.registerDevice(authToken: token);

      if (!mounted) return;

      setState(() {
        _step = _RegisterStep.done;
      });
    } on EmailAlreadyRegisteredException {
      if (!mounted) return;

      setState(() {
        _step = _RegisterStep.account;
        _errorMessage = 'Ya existe una cuenta con ese email.';
      });
    } on _OnboardingPhotoException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'No se pudo finalizar el registro. Revisa los datos e intentalo otra vez.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<String> _ensureRegisteredAndLoggedIn() async {
    if (_authToken != null && _authToken!.isNotEmpty) {
      return _authToken!;
    }

    await _authApi.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _fullNameController.text.trim(),
      role: _selectedRole,
    );

    final token = await _authApi.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    await _authApi.me(token);
    _authToken = token;

    return token;
  }

  Future<void> _pickProfilePhoto() async {
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
        _selectedProfilePhotoFile = File(image.path);
        _profilePhotoUploaded = false;
        _errorMessage = null;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'No se pudo seleccionar la foto.';
      });
    }
  }

  Future<void> _uploadSelectedProfilePhoto(String token) async {
    final file = _selectedProfilePhotoFile;

    if (file == null) {
      return;
    }

    try {
      await _profileApi.uploadMyProfilePhoto(token: token, file: file);
    } on UnsupportedProfilePhotoTypeException {
      throw const _OnboardingPhotoException(
        'Formato no valido. Usa JPG, PNG o WebP.',
      );
    } on ProfilePhotoTooLargeException {
      throw const _OnboardingPhotoException('La foto no puede superar 5 MB.');
    }
  }

  Future<void> _validateSelectedProfilePhoto() async {
    final file = _selectedProfilePhotoFile;

    if (file == null) {
      return;
    }

    if (ImageUploadRules.contentTypeForPath(file.path) == null) {
      throw const _OnboardingPhotoException(
        'Formato no valido. Usa JPG, PNG o WebP.',
      );
    }

    if (await ImageUploadRules.isTooLarge(file)) {
      throw const _OnboardingPhotoException('La foto no puede superar 5 MB.');
    }
  }

  Future<void> _enterApp() async {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => OpportunitiesListScreen(tokenStore: _tokenStore),
      ),
      (_) => false,
    );
  }

  Future<void> _showPrivacyInfo() async {
    if (_isLoading) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _PrivacyInfoSheet(),
    );
  }

  void _toggleInstrument(CatalogItem item) {
    setState(() {
      if (_selectedInstrumentIds.contains(item.id)) {
        _selectedInstrumentIds.remove(item.id);
        if (_primaryInstrumentId == item.id) {
          _primaryInstrumentId = _selectedInstrumentIds.isEmpty
              ? null
              : _selectedInstrumentIds.first;
        }
      } else {
        _selectedInstrumentIds.add(item.id);
        _primaryInstrumentId ??= item.id;
      }
    });
  }

  void _toggleStyle(CatalogItem item) {
    setState(() {
      if (_selectedStyleIds.contains(item.id)) {
        _selectedStyleIds.remove(item.id);
      } else {
        _selectedStyleIds.add(item.id);
      }
    });
  }

  void _toggleOpportunityType(OpportunityType type) {
    setState(() {
      if (_selectedOpportunityTypeIds.contains(type.id)) {
        _selectedOpportunityTypeIds.remove(type.id);
      } else {
        _selectedOpportunityTypeIds.add(type.id);
      }
    });
  }

  void _toggleAlertInstrument(CatalogItem item) {
    setState(() {
      if (_selectedAlertInstrumentIds.contains(item.id)) {
        _selectedAlertInstrumentIds.remove(item.id);
      } else {
        _selectedAlertInstrumentIds.add(item.id);
      }
    });
  }

  void _toggleAlertStyle(CatalogItem item) {
    setState(() {
      if (_selectedAlertStyleIds.contains(item.id)) {
        _selectedAlertStyleIds.remove(item.id);
      } else {
        _selectedAlertStyleIds.add(item.id);
      }
    });
  }

  int? _resolvedPrimaryInstrumentId() {
    final primaryInstrumentId = _primaryInstrumentId;

    if (primaryInstrumentId != null &&
        _selectedInstrumentIds.contains(primaryInstrumentId)) {
      return primaryInstrumentId;
    }

    if (_selectedInstrumentIds.isEmpty) {
      return null;
    }

    return _selectedInstrumentIds.first;
  }

  String? _textOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  _RegisterStep _previousStep(_RegisterStep step) {
    return switch (step) {
      _RegisterStep.role => _RegisterStep.account,
      _RegisterStep.profile => _RegisterStep.role,
      _RegisterStep.alerts => _RegisterStep.profile,
      _RegisterStep.account || _RegisterStep.done => _RegisterStep.account,
    };
  }

  String _screenTitle() {
    return switch (_step) {
      _RegisterStep.account => 'Crear cuenta',
      _RegisterStep.role => 'Selecciona tu rol',
      _RegisterStep.profile => 'Completar tu perfil',
      _RegisterStep.alerts => 'Configura tus alertas',
      _RegisterStep.done => '',
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _step == _RegisterStep.done
          ? null
          : AppBar(
              title: Text(_screenTitle()),
              centerTitle: true,
              leading: IconButton(
                icon: const Icon(Icons.chevron_left_rounded),
                onPressed: _goBack,
              ),
            ),
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_step == _RegisterStep.account) {
      return _buildAccountStep();
    }

    if (_step == _RegisterStep.role) {
      return _buildRoleStep();
    }

    if (_step == _RegisterStep.done) {
      return _buildDoneStep();
    }

    return FutureBuilder<_OnboardingCatalogs>(
      future: _catalogsFuture,
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          final catalogs = snapshot.data!;

          if (_step == _RegisterStep.profile) {
            return _buildProfileStep(catalogs);
          }

          return _buildAlertsStep(catalogs);
        }

        if (snapshot.hasError) {
          return _CatalogLoadError(onRetry: _retryCatalogs);
        }

        return const Center(child: CircularProgressIndicator());
      },
    );
  }

  Widget _buildAccountStep() {
    return _StepList(
      children: [
        Text(
          'Crea tu cuenta en MusiHub',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 6),
        Text(
          'Usaremos estos datos para crear tu identidad dentro de la comunidad musical.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 26),
        _LabeledField(
          label: 'Nombre completo',
          child: TextField(
            controller: _fullNameController,
            maxLength: InputLimits.fullName,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Introduce tu nombre y apellidos',
              counterText: '',
            ),
          ),
        ),
        _LabeledField(
          label: 'Email',
          child: TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            maxLength: InputLimits.email,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Introduce tu email',
              counterText: '',
            ),
          ),
        ),
        _LabeledField(
          label: 'Contrasena',
          child: TextField(
            controller: _passwordController,
            obscureText: true,
            maxLength: InputLimits.password,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              hintText: 'Minimo 8 caracteres',
              counterText: '',
            ),
          ),
        ),
        _LabeledField(
          label: 'Repite tu contrasena',
          child: TextField(
            controller: _repeatPasswordController,
            obscureText: true,
            maxLength: InputLimits.password,
            onSubmitted: (_) => _continue(catalogs: null),
            decoration: const InputDecoration(
              hintText: 'Repite tu contrasena anterior',
              counterText: '',
            ),
          ),
        ),
        _StepError(message: _errorMessage),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isLoading ? null : () => _continue(catalogs: null),
          child: const Text('Continuar'),
        ),
        _LoginFooter(onTap: _goToLogin),
      ],
    );
  }

  Widget _buildRoleStep() {
    return _StepList(
      children: [
        const _StepProgress(currentStep: 1),
        const SizedBox(height: 24),
        Text(
          'Elige el tipo de perfil que mas te represente',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        for (final role in _roles) ...[
          _RoleCard(
            role: role,
            selected: _selectedRole == role.code,
            onTap: () {
              setState(() {
                _selectedRole = role.code;
              });
            },
          ),
          const SizedBox(height: 12),
        ],
        _StepError(message: _errorMessage),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isLoading ? null : () => _continue(catalogs: null),
          child: const Text('Continuar'),
        ),
        _LoginFooter(onTap: _goToLogin),
      ],
    );
  }

  Widget _buildProfileStep(_OnboardingCatalogs catalogs) {
    return _StepList(
      children: [
        const _StepProgress(currentStep: 2),
        const SizedBox(height: 24),
        Text(
          'Anade informacion basica para que otros puedan conocerte mejor.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        PhotoPickerPanel(
          localPhotoPath: _selectedProfilePhotoFile?.path,
          onTap: _isLoading ? null : _pickProfilePhoto,
          placeholderIcon: Icons.person_outline,
        ),
        const SizedBox(height: 26),
        _LabeledField(
          label: 'Ubicacion',
          child: LocationSelector(
            locations: catalogs.locations,
            provinceController: _provinceController,
            cityController: _cityController,
            requireProvince: false,
            requireCity: false,
          ),
        ),
        _ChipSection(
          title: 'Instrumentos',
          subtitle: 'El primero que selecciones sera tu instrumento principal',
          items: catalogs.instruments,
          selectedIds: _selectedInstrumentIds,
          onTap: _toggleInstrument,
        ),
        const SizedBox(height: 18),
        _ChipSection(
          title: 'Estilos musicales',
          items: catalogs.styles,
          selectedIds: _selectedStyleIds,
          onTap: _toggleStyle,
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: 'Telefono de contacto',
          child: TextField(
            controller: _contactPhoneController,
            keyboardType: TextInputType.phone,
            maxLength: InputLimits.phone,
            inputFormatters: InputLimits.phoneFormatters,
            decoration: const InputDecoration(
              hintText: 'Opcional',
              counterText: '',
            ),
          ),
        ),
        Text(
          'Tu email de cuenta se guardara como contacto por defecto. Podras cambiarlo desde Perfil.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        _LabeledField(
          label: 'Cuenta un poco sobre ti',
          child: TextField(
            controller: _bioController,
            maxLength: InputLimits.profileBio,
            maxLines: 5,
            decoration: const InputDecoration(
              hintText:
                  'Que buscas, que te apasiona, que experiencia tienes...',
              counterText: '',
            ),
          ),
        ),
        _StepError(message: _errorMessage),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isLoading ? null : () => _continue(catalogs: catalogs),
          child: const Text('Continuar'),
        ),
      ],
    );
  }

  Widget _buildAlertsStep(_OnboardingCatalogs catalogs) {
    return _StepList(
      children: [
        const _StepProgress(currentStep: 3),
        const SizedBox(height: 24),
        const Center(
          child: MusiHubLogoMark(size: 64, icon: Icons.notifications_rounded),
        ),
        const SizedBox(height: 22),
        Text(
          'No te pierdas ninguna oportunidad',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          'Personaliza las alertas segun tus intereses. Podras modificarlas cuando quieras.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 26),
        _AlertActivationTile(
          enabled: _notificationsEnabled,
          onChanged: (value) {
            setState(() {
              _notificationsEnabled = value;
            });
          },
        ),
        const SizedBox(height: 18),
        Text(
          'Recibir alertas sobre:',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 10),
        for (final type in catalogs.opportunityTypes) ...[
          _OpportunityTypeTile(
            type: type,
            selected: _selectedOpportunityTypeIds.contains(type.id),
            onTap: () => _toggleOpportunityType(type),
          ),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 14),
        _ChipSection(
          title: 'Instrumentos de interes',
          subtitle: 'Si no eliges ninguno, no se filtra por instrumento',
          items: catalogs.instruments,
          selectedIds: _selectedAlertInstrumentIds,
          onTap: _toggleAlertInstrument,
        ),
        const SizedBox(height: 18),
        _ChipSection(
          title: 'Estilos de interes',
          subtitle: 'Si no eliges ninguno, no se filtra por estilo',
          items: catalogs.styles,
          selectedIds: _selectedAlertStyleIds,
          onTap: _toggleAlertStyle,
        ),
        const SizedBox(height: 10),
        _PrivacyConsentCard(
          accepted: _privacyAccepted,
          onChanged: (value) {
            setState(() {
              _privacyAccepted = value;
              if (value) {
                _errorMessage = null;
              }
            });
          },
          onOpenPrivacy: _showPrivacyInfo,
        ),
        _StepError(message: _errorMessage),
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _isLoading ? null : () => _continue(catalogs: catalogs),
          child: Text(_isLoading ? 'Finalizando...' : 'Finalizar'),
        ),
      ],
    );
  }

  Widget _buildDoneStep() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 70, 28, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),
          const Center(
            child: MusiHubLogoMark(size: 76, icon: Icons.star_rounded),
          ),
          const SizedBox(height: 28),
          Text(
            'Perfil finalizado',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 12),
          Text(
            'Enhorabuena. Ya puedes empezar a usar MusiHub.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const Spacer(),
          FilledButton(
            onPressed: _enterApp,
            child: const Text('Continuar a la app'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingCatalogs {
  const _OnboardingCatalogs({
    required this.instruments,
    required this.styles,
    required this.opportunityTypes,
    required this.locations,
  });

  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<OpportunityType> opportunityTypes;
  final List<LocationProvince> locations;
}

class _RoleOption {
  const _RoleOption({
    required this.code,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String code;
  final String title;
  final String subtitle;
  final IconData icon;
}

class _OnboardingPhotoException implements Exception {
  const _OnboardingPhotoException(this.message);

  final String message;
}
