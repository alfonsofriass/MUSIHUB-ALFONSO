import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/bands/band_detail_screen.dart';
import 'package:musihub_front/features/contact_requests/contact_requests_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/opportunities/widgets/opportunity_detail_widgets.dart';
import 'package:musihub_front/features/profile/public_profile_screen.dart';
import 'package:share_plus/share_plus.dart';

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

  late final AuthApi _authApi;
  late final ContactRequestsApi _contactRequestsApi;
  late final OpportunitiesApi _opportunitiesApi;
  late Future<_OpportunityDetailData> _detailFuture;

  bool _isRequestingContact = false;

  @override
  void initState() {
    super.initState();
    _authApi = AuthApi(apiClient: _apiClient);
    _contactRequestsApi = ContactRequestsApi(apiClient: _apiClient);
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

    final opportunityFuture = _opportunitiesApi.getOpportunity(
      widget.opportunityId,
      token: token,
    );
    final favoritesFuture = _opportunitiesApi.listFavoriteOpportunities(token);
    final userFuture = _authApi.me(token);
    final sentRequestsFuture = _contactRequestsApi.listSent(token);

    final opportunity = await opportunityFuture;
    final favorites = await favoritesFuture;
    final user = await userFuture;
    final sentRequests = await sentRequestsFuture;
    final contactRequestStatus = _contactRequestStatusForOpportunity(
      sentRequests: sentRequests,
      opportunityId: opportunity.id,
    );

    return _OpportunityDetailData(
      opportunity: opportunity,
      isFavorite: favorites.any((favorite) => favorite.id == opportunity.id),
      currentUserId: user.id,
      contactRequestStatus: contactRequestStatus,
    );
  }

  void _refresh() {
    setState(() {
      _detailFuture = _loadDetailData();
    });
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

  Future<void> _requestContact(_OpportunityDetailData data) async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isRequestingContact = true;
    });

    try {
      await _contactRequestsApi.createContactRequest(
        token: token,
        opportunityId: data.opportunity.id,
      );

      if (!mounted) return;

      setState(() {
        _detailFuture = Future.value(
          data.copyWith(contactRequestStatus: 'pending'),
        );
      });
    } on DuplicateContactRequestException {
      if (!mounted) return;

      setState(() {
        _detailFuture = Future.value(
          data.copyWith(contactRequestStatus: 'pending'),
        );
      });
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo solicitar el contacto.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isRequestingContact = false;
        });
      }
    }
  }

  Future<void> _openAuthorProfile(Opportunity opportunity) async {
    final authorUserId = opportunity.authorUser?.id ?? opportunity.authorUserId;

    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          tokenStore: widget.tokenStore,
          userId: authorUserId,
        ),
      ),
    );
  }

  Future<void> _openAuthorBand(OpportunityAuthorBand band) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) =>
            BandDetailScreen(tokenStore: widget.tokenStore, bandId: band.id),
      ),
    );
  }

  Future<void> _shareOpportunity(
    BuildContext shareContext,
    Opportunity opportunity,
  ) async {
    final box = shareContext.findRenderObject() as RenderBox?;

    await SharePlus.instance.share(
      ShareParams(
        title: opportunity.title,
        subject: opportunity.title,
        text: _shareTextForOpportunity(opportunity),
        sharePositionOrigin: box == null
            ? null
            : box.localToGlobal(Offset.zero) & box.size,
      ),
    );
  }

  String _shareTextForOpportunity(Opportunity opportunity) {
    final lines = <String>[
      'Mira esta oportunidad en MusiHub:',
      '',
      opportunity.title,
      opportunity.type.name,
      _locationLabel(opportunity),
    ];

    if (opportunity.eventDate != null) {
      lines.add('Fecha: ${opportunityLongDateLabel(opportunity.eventDate!)}');
    }

    if (opportunity.priceAmount != null) {
      lines.add('Precio: ${opportunityPriceLabel(opportunity.priceAmount!)}');
    }

    lines
      ..add('')
      ..add(_shortShareDescription(opportunity.description))
      ..add('')
      ..add('Abre MusiHub para ver el anuncio completo.');

    return lines.join('\n');
  }

  String _locationLabel(Opportunity opportunity) {
    final province = opportunity.province;

    if (province == null || province.trim().isEmpty) {
      return opportunity.city;
    }

    if (province == opportunity.city) {
      return opportunity.city;
    }

    return '${opportunity.city}, $province';
  }

  String _shortShareDescription(String description) {
    final normalized = description.trim().replaceAll(RegExp(r'\s+'), ' ');

    if (normalized.length <= 180) {
      return normalized;
    }

    return '${normalized.substring(0, 177)}...';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalles Anuncio'),
        centerTitle: true,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: MusiHubColors.borderGrey),
        ),
        actions: [
          FutureBuilder<_OpportunityDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;

              return Builder(
                builder: (shareContext) {
                  return IconButton(
                    onPressed: data == null
                        ? null
                        : () =>
                              _shareOpportunity(shareContext, data.opportunity),
                    icon: const Icon(Icons.share_outlined),
                    tooltip: 'Compartir',
                  );
                },
              );
            },
          ),
          FutureBuilder<_OpportunityDetailData>(
            future: _detailFuture,
            builder: (context, snapshot) {
              final data = snapshot.data;

              if (data != null &&
                  data.opportunity.authorUserId == data.currentUserId) {
                return const SizedBox.shrink();
              }

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
              return OpportunityDetailContent(
                opportunity: snapshot.data!.opportunity,
                currentUserId: snapshot.data!.currentUserId,
                contactRequestStatus: snapshot.data!.contactRequestStatus,
                isRequestingContact: _isRequestingContact,
                onRequestContact: () => _requestContact(snapshot.data!),
                onOpenAuthorProfile: () =>
                    _openAuthorProfile(snapshot.data!.opportunity),
                onOpenAuthorBand: snapshot.data!.opportunity.authorBand == null
                    ? null
                    : () => _openAuthorBand(
                        snapshot.data!.opportunity.authorBand!,
                      ),
              );
            }

            if (snapshot.hasError) {
              return OpportunityLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _OpportunityDetailData {
  const _OpportunityDetailData({
    required this.opportunity,
    required this.isFavorite,
    required this.currentUserId,
    required this.contactRequestStatus,
  });

  final Opportunity opportunity;
  final bool isFavorite;
  final int currentUserId;
  final String? contactRequestStatus;

  _OpportunityDetailData copyWith({
    bool? isFavorite,
    String? contactRequestStatus,
  }) {
    return _OpportunityDetailData(
      opportunity: opportunity,
      isFavorite: isFavorite ?? this.isFavorite,
      currentUserId: currentUserId,
      contactRequestStatus: contactRequestStatus ?? this.contactRequestStatus,
    );
  }
}

String? _contactRequestStatusForOpportunity({
  required List<ContactRequestItem> sentRequests,
  required int opportunityId,
}) {
  for (final request in sentRequests) {
    if (request.opportunity.id == opportunityId) {
      return request.status;
    }
  }

  return null;
}
