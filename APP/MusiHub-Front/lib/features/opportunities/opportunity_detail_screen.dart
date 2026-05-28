import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/auth/auth_api.dart';
import 'package:musihub_front/features/bands/band_detail_screen.dart';
import 'package:musihub_front/features/contact_requests/contact_requests_api.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/public_profile_screen.dart';

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
              return _OpportunityLoadError(onRetry: _refresh);
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

class _OpportunityDetail extends StatelessWidget {
  const _OpportunityDetail({
    required this.opportunity,
    required this.currentUserId,
    required this.contactRequestStatus,
    required this.isRequestingContact,
    required this.onRequestContact,
    required this.onOpenAuthorProfile,
    required this.onOpenAuthorBand,
  });

  final Opportunity opportunity;
  final int currentUserId;
  final String? contactRequestStatus;
  final bool isRequestingContact;
  final VoidCallback onRequestContact;
  final VoidCallback onOpenAuthorProfile;
  final VoidCallback? onOpenAuthorBand;

  @override
  Widget build(BuildContext context) {
    final isOwnOpportunity = opportunity.authorUserId == currentUserId;

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
        _AuthorSection(
          opportunity: opportunity,
          onOpenProfile: onOpenAuthorProfile,
          onOpenBand: onOpenAuthorBand,
        ),
        const SizedBox(height: 16),
        _ContactAction(
          opportunity: opportunity,
          isOwnOpportunity: isOwnOpportunity,
          contactRequestStatus: contactRequestStatus,
          isRequestingContact: isRequestingContact,
          onRequestContact: onRequestContact,
        ),
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
      for (final instrument in opportunity.instruments)
        _TagData(label: instrument.name),
      for (final style in opportunity.styles) _TagData(label: style.name),
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

class _AuthorSection extends StatelessWidget {
  const _AuthorSection({
    required this.opportunity,
    required this.onOpenProfile,
    required this.onOpenBand,
  });

  final Opportunity opportunity;
  final VoidCallback onOpenProfile;
  final VoidCallback? onOpenBand;

  @override
  Widget build(BuildContext context) {
    final authorBand = opportunity.authorBand;
    final authorUserLabel =
        opportunity.authorUser?.fullName ??
        'Usuario #${opportunity.authorUserId}';

    return Column(
      children: [
        _AuthorTile(
          icon: Icons.person_outline,
          title: authorUserLabel,
          subtitle: 'Perfil',
          onTap: onOpenProfile,
        ),
        if (authorBand != null) ...[
          const SizedBox(height: 8),
          _AuthorTile(
            icon: Icons.groups_outlined,
            title: authorBand.name,
            subtitle: 'Banda',
            onTap: onOpenBand,
          ),
        ],
      ],
    );
  }
}

class _AuthorTile extends StatelessWidget {
  const _AuthorTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFD0D0D0),
      borderRadius: BorderRadius.circular(4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFF9A9A9A)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: const Color(0xFF8F8F8F),
                child: Icon(icon, size: 18, color: Colors.white),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                    Text(
                      subtitle,
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
      ),
    );
  }
}

class _ContactAction extends StatelessWidget {
  const _ContactAction({
    required this.opportunity,
    required this.isOwnOpportunity,
    required this.contactRequestStatus,
    required this.isRequestingContact,
    required this.onRequestContact,
  });

  final Opportunity opportunity;
  final bool isOwnOpportunity;
  final String? contactRequestStatus;
  final bool isRequestingContact;
  final VoidCallback onRequestContact;

  @override
  Widget build(BuildContext context) {
    final contactValue = opportunity.contactValue;

    if (contactValue != null && contactValue.trim().isNotEmpty) {
      return _ContactInfoCard(
        method: _contactMethodLabel(opportunity.contactMethod),
        value: contactValue,
      );
    }

    if (!opportunity.isActive) {
      return const _ContactNotice(
        icon: Icons.lock_outline,
        text: 'Este anuncio esta cerrado y ya no acepta solicitudes.',
      );
    }

    if (isOwnOpportunity) {
      return const _ContactNotice(
        icon: Icons.lock_outline,
        text: 'Tu dato de contacto no esta visible publicamente.',
      );
    }

    if (contactRequestStatus == 'pending') {
      return const _ContactStateNotice(
        icon: Icons.mark_email_unread_outlined,
        text: 'Solicitud enviada',
        detail: 'El anunciante todavia no ha respondido.',
      );
    }

    if (contactRequestStatus == 'rejected') {
      return const _ContactStateNotice(
        icon: Icons.block_outlined,
        text: 'Solicitud rechazada',
        detail: 'El anunciante no ha aceptado compartir el contacto.',
        muted: true,
      );
    }

    if (contactRequestStatus == 'accepted') {
      return const _ContactStateNotice(
        icon: Icons.mark_email_read_outlined,
        text: 'Solicitud aceptada',
        detail: 'El contacto todavia no esta disponible.',
      );
    }

    return FilledButton.icon(
      onPressed: isRequestingContact ? null : onRequestContact,
      icon: const Icon(Icons.mail_outline),
      label: Text(
        isRequestingContact ? 'Solicitando...' : 'Solicitar contacto',
      ),
    );
  }

  String _contactMethodLabel(String method) {
    switch (method) {
      case 'whatsapp':
        return 'WhatsApp';
      case 'email':
        return 'Email';
      case 'phone':
        return 'Telefono';
      default:
        return 'Contacto';
    }
  }
}

class _ContactStateNotice extends StatelessWidget {
  const _ContactStateNotice({
    required this.icon,
    required this.text,
    required this.detail,
    this.muted = false,
  });

  final IconData icon;
  final String text;
  final String detail;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final color = muted ? MusiHubColors.textGrey : MusiHubColors.primary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: color),
                ),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard({required this.method, required this.value});

  final String method;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: MusiHubColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                color: MusiHubColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(method, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactNotice extends StatelessWidget {
  const _ContactNotice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(icon, color: MusiHubColors.textGrey),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
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
