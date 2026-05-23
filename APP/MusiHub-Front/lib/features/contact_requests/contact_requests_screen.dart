import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/contact_requests/contact_requests_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_detail_screen.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';

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

              if (requests.isEmpty) {
                return _EmptyContactRequests(isReceivedMode: _isReceivedMode);
              }

              return ListView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
                children: [
                  Text(title, style: Theme.of(context).textTheme.headlineLarge),
                  const SizedBox(height: 16),
                  for (final request in requests) ...[
                    _ContactRequestCard(
                      request: request,
                      isReceivedMode: _isReceivedMode,
                      isUpdating: _updatingRequestId == request.id,
                      onOpen: () => _openOpportunity(request),
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
    required this.onAccept,
    required this.onReject,
  });

  final ContactRequestItem request;
  final bool isReceivedMode;
  final bool isUpdating;
  final VoidCallback onOpen;
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
                  Expanded(
                    child: Text(
                      opportunity.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 10),
                  _RequestStatusBadge(status: request.status),
                ],
              ),
              const SizedBox(height: 8),
              if (isReceivedMode && requester != null) ...[
                _SmallInfo(
                  icon: Icons.person_outline,
                  text: 'Solicita: ${requester.fullName}',
                ),
                const SizedBox(height: 6),
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
                _AcceptedContactInfo(
                  method: _contactMethodLabel(opportunity.contactMethod),
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

class _AcceptedContactInfo extends StatelessWidget {
  const _AcceptedContactInfo({required this.method, required this.value});

  final String method;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: MusiHubColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(method, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 3),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}

class _SmallInfo extends StatelessWidget {
  const _SmallInfo({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: MusiHubColors.textGrey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          isReceivedMode
              ? 'Todavia no has recibido solicitudes de contacto.'
              : 'Todavia no has enviado solicitudes de contacto.',
          textAlign: TextAlign.center,
        ),
      ),
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
