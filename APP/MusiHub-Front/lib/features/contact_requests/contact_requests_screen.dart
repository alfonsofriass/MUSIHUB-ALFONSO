import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/contact_action_tile.dart';
import 'package:musihub_front/core/widgets/musihub_empty_state.dart';
import 'package:musihub_front/features/contact_requests/contact_requests_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';
import 'package:musihub_front/features/profile/public_profile_screen.dart';

enum ContactRequestsScreenMode { received, sent }

class ContactRequestsScreen extends StatefulWidget {
  const ContactRequestsScreen({
    super.key,
    required this.tokenStore,
    required this.mode,
  });

  final TokenStore tokenStore;
  final ContactRequestsScreenMode mode;

  @override
  State<ContactRequestsScreen> createState() => _ContactRequestsScreenState();
}

class _ContactRequestsScreenState extends State<ContactRequestsScreen> {
  final _apiClient = ApiClient();

  late final ContactRequestsApi _contactRequestsApi;
  late Future<List<ContactRequestItem>> _requestsFuture;

  String? _token;
  int? _updatingRequestId;

  bool get _isReceivedMode => widget.mode == ContactRequestsScreenMode.received;

  @override
  void initState() {
    super.initState();
    _contactRequestsApi = ContactRequestsApi(apiClient: _apiClient);
    _requestsFuture = _loadRequests();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<List<ContactRequestItem>> _loadRequests() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesion activa.');
    }

    _token = token;

    return _isReceivedMode
        ? _contactRequestsApi.listReceived(token)
        : _contactRequestsApi.listSent(token);
  }

  void _refresh() {
    setState(() {
      _requestsFuture = _loadRequests();
    });
  }

  Future<void> _openOpportunity(ContactRequestItem request) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => OpportunityDetailScreen(
          opportunityId: request.opportunity.id,
          tokenStore: widget.tokenStore,
        ),
      ),
    );

    if (!mounted) return;

    _refresh();
  }

  Future<void> _openRequesterProfile(ContactRequestUser requester) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PublicProfileScreen(
          tokenStore: widget.tokenStore,
          userId: requester.id,
        ),
      ),
    );
  }

  Future<void> _respond(ContactRequestItem request, bool accept) async {
    final token = _token;

    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _updatingRequestId = request.id;
    });

    try {
      if (accept) {
        await _contactRequestsApi.accept(
          token: token,
          contactRequestId: request.id,
        );
      } else {
        await _contactRequestsApi.reject(
          token: token,
          contactRequestId: request.id,
        );
      }

      if (!mounted) return;

      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept
                ? 'No se pudo aceptar la solicitud.'
                : 'No se pudo rechazar la solicitud.',
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingRequestId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isReceivedMode
        ? 'Solicitudes recibidas'
        : 'Solicitudes enviadas';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: FutureBuilder<List<ContactRequestItem>>(
          future: _requestsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              final requests = snapshot.data!;

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 6),
                  Text(
                    _isReceivedMode
                        ? 'Personas interesadas en tus anuncios.'
                        : 'Solicitudes que has enviado para desbloquear contacto.',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  if (requests.isEmpty)
                    _EmptyContactRequests(isReceivedMode: _isReceivedMode)
                  else
                    _ContactRequestsHint(isReceivedMode: _isReceivedMode),
                  if (requests.isNotEmpty) const SizedBox(height: 16),
                  for (final request in requests) ...[
                    _ContactRequestCard(
                      request: request,
                      isReceivedMode: _isReceivedMode,
                      isUpdating: _updatingRequestId == request.id,
                      onOpen: () => _openOpportunity(request),
                      onOpenRequesterProfile: request.requester == null
                          ? null
                          : () => _openRequesterProfile(request.requester!),
                      onAccept: request.isPending
                          ? () => _respond(request, true)
                          : null,
                      onReject: request.isPending
                          ? () => _respond(request, false)
                          : null,
                    ),
                    const SizedBox(height: 14),
                  ],
                ],
              );
            }

            if (snapshot.hasError) {
              return _ContactRequestsLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _ContactRequestCard extends StatelessWidget {
  const _ContactRequestCard({
    required this.request,
    required this.isReceivedMode,
    required this.isUpdating,
    required this.onOpen,
    required this.onOpenRequesterProfile,
    required this.onAccept,
    required this.onReject,
  });

  final ContactRequestItem request;
  final bool isReceivedMode;
  final bool isUpdating;
  final VoidCallback onOpen;
  final VoidCallback? onOpenRequesterProfile;
  final VoidCallback? onAccept;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final opportunity = request.opportunity;
    final requester = request.requester;

    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: MusiHubColors.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isReceivedMode
                          ? Icons.mark_email_unread_outlined
                          : Icons.outgoing_mail,
                      size: 20,
                      color: MusiHubColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isReceivedMode
                              ? 'Solicitud recibida'
                              : 'Solicitud enviada',
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _dateLabel(request.createdAt),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RequestStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                opportunity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (isReceivedMode && requester != null) ...[
                _RequesterProfileTile(
                  requesterName: requester.fullName,
                  onTap: onOpenRequesterProfile,
                ),
                const SizedBox(height: 10),
              ],
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.category_outlined,
                    text: opportunity.type.name,
                  ),
                  _MetaItem(
                    icon: Icons.location_on_outlined,
                    text: opportunity.city,
                  ),
                  if (opportunity.priceAmount != null)
                    _MetaItem(
                      icon: Icons.euro,
                      text: opportunityPriceLabel(opportunity.priceAmount!),
                    ),
                ],
              ),
              if (!isReceivedMode &&
                  request.isAccepted &&
                  opportunity.contactValue != null) ...[
                const SizedBox(height: 12),
                ContactActionTile(
                  method: opportunity.contactMethod,
                  value: opportunity.contactValue!,
                ),
              ],
              if (isReceivedMode && request.isPending) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: isUpdating ? null : onReject,
                        child: const Text('Rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: isUpdating ? null : onAccept,
                        child: Text(isUpdating ? 'Guardando...' : 'Aceptar'),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dateLabel(String value) {
    final date = DateTime.tryParse(value);
    if (date == null) {
      return value;
    }

    final localDate = date.toLocal();
    return '${_twoDigits(localDate.day)}/${_twoDigits(localDate.month)}/${localDate.year}';
  }

  String _twoDigits(int value) {
    return value.toString().padLeft(2, '0');
  }
}

class _RequestStatusBadge extends StatelessWidget {
  const _RequestStatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'accepted' => 'Aceptada',
      'rejected' => 'Rechazada',
      _ => 'Pendiente',
    };
    final color = switch (status) {
      'accepted' => MusiHubColors.primary,
      'rejected' => Colors.redAccent,
      _ => MusiHubColors.textGrey,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ContactRequestsHint extends StatelessWidget {
  const _ContactRequestsHint({required this.isReceivedMode});

  final bool isReceivedMode;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MusiHubColors.primary.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 18,
            color: MusiHubColors.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isReceivedMode
                  ? 'Acepta una solicitud para que esa persona vea tu dato de contacto.'
                  : 'Cuando una solicitud sea aceptada, aqui veras el contacto del anuncio.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _RequesterProfileTile extends StatelessWidget {
  const _RequesterProfileTile({
    required this.requesterName,
    required this.onTap,
  });

  final String requesterName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: MusiHubColors.fieldGrey,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: MusiHubColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline,
                  size: 18,
                  color: MusiHubColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Solicitado por',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      requesterName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: MusiHubColors.textGrey,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetaItem extends StatelessWidget {
  const _MetaItem({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: MusiHubColors.textGrey),
        const SizedBox(width: 3),
        Text(text, style: Theme.of(context).textTheme.titleSmall),
      ],
    );
  }
}

class _EmptyContactRequests extends StatelessWidget {
  const _EmptyContactRequests({required this.isReceivedMode});

  final bool isReceivedMode;

  @override
  Widget build(BuildContext context) {
    return MusiHubEmptyState(
      icon: isReceivedMode
          ? Icons.mark_email_unread_outlined
          : Icons.outgoing_mail,
      title: isReceivedMode
          ? 'Sin solicitudes recibidas'
          : 'Sin solicitudes enviadas',
      message: isReceivedMode
          ? 'Cuando alguien quiera contactar por uno de tus anuncios, aparecera aqui.'
          : 'Cuando solicites contacto desde un anuncio, podras seguir aqui su estado.',
    );
  }
}

class _ContactRequestsLoadError extends StatelessWidget {
  const _ContactRequestsLoadError({required this.onRetry});

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
              'No se pudieron cargar las solicitudes.',
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
