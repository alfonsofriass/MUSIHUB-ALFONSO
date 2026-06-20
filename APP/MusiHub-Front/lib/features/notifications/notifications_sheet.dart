import 'package:flutter/material.dart';
import 'package:musihub_front/core/api/api_client.dart';
import 'package:musihub_front/core/formatters/date_formatters.dart';
import 'package:musihub_front/core/session/token_store.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/musihub_empty_state.dart';
import 'package:musihub_front/features/notifications/notifications_api.dart';

Future<void> showNotificationsSheet({
  required BuildContext context,
  required TokenStore tokenStore,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.82,
      child: _NotificationsSheet(tokenStore: tokenStore),
    ),
  );
}

class _NotificationsSheet extends StatefulWidget {
  const _NotificationsSheet({required this.tokenStore});

  final TokenStore tokenStore;

  @override
  State<_NotificationsSheet> createState() => _NotificationsSheetState();
}

class _NotificationsSheetState extends State<_NotificationsSheet> {
  final _apiClient = ApiClient();

  late final NotificationsApi _notificationsApi;
  late Future<NotificationsResponse> _notificationsFuture;

  String? _token;
  int? _updatingNotificationId;
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _notificationsApi = NotificationsApi(apiClient: _apiClient);
    _notificationsFuture = _loadNotifications();
  }

  @override
  void dispose() {
    _apiClient.close();
    super.dispose();
  }

  Future<NotificationsResponse> _loadNotifications() async {
    final token = await widget.tokenStore.readAccessToken();

    if (token == null || token.isEmpty) {
      throw Exception('No hay sesión activa.');
    }

    _token = token;
    return _notificationsApi.listNotifications(token);
  }

  void _refresh() {
    setState(() {
      _notificationsFuture = _loadNotifications();
    });
  }

  Future<void> _markAsRead(AppNotification notification) async {
    final token = _token;

    if (token == null || token.isEmpty || !notification.isUnread) {
      return;
    }

    setState(() {
      _updatingNotificationId = notification.id;
    });

    try {
      await _notificationsApi.markAsRead(
        token: token,
        notificationId: notification.id,
      );

      if (!mounted) return;
      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo marcar como leída.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _updatingNotificationId = null;
        });
      }
    }
  }

  Future<void> _markAllAsRead() async {
    final token = _token;

    if (token == null || token.isEmpty) {
      return;
    }

    setState(() {
      _isMarkingAll = true;
    });

    try {
      await _notificationsApi.markAllAsRead(token);

      if (!mounted) return;
      _refresh();
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudieron marcar las notificaciones.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isMarkingAll = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: FutureBuilder<NotificationsResponse>(
          future: _notificationsFuture,
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              return _NotificationsSheetContent(
                response: snapshot.data!,
                updatingNotificationId: _updatingNotificationId,
                isMarkingAll: _isMarkingAll,
                onMarkAsRead: _markAsRead,
                onMarkAllAsRead: _markAllAsRead,
              );
            }

            if (snapshot.hasError) {
              return _NotificationsLoadError(onRetry: _refresh);
            }

            return const Center(child: CircularProgressIndicator());
          },
        ),
      ),
    );
  }
}

class _NotificationsSheetContent extends StatelessWidget {
  const _NotificationsSheetContent({
    required this.response,
    required this.updatingNotificationId,
    required this.isMarkingAll,
    required this.onMarkAsRead,
    required this.onMarkAllAsRead,
  });

  final NotificationsResponse response;
  final int? updatingNotificationId;
  final bool isMarkingAll;
  final ValueChanged<AppNotification> onMarkAsRead;
  final VoidCallback onMarkAllAsRead;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _SheetHandle(),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: Text(
                'Notificaciones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
              tooltip: 'Cerrar',
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            response.unreadCount == 0
                ? 'No tienes notificaciones pendientes.'
                : '${response.unreadCount} sin leer',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        if (response.unreadCount > 0) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: isMarkingAll ? null : onMarkAllAsRead,
            icon: const Icon(Icons.done_all),
            label: Text(isMarkingAll ? 'Marcando...' : 'Marcar todas leídas'),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(
          child: response.items.isEmpty
              ? const MusiHubEmptyState(
                  icon: Icons.notifications_none,
                  title: 'Sin notificaciones',
                  message: 'Aquí aparecerán alertas y solicitudes importantes.',
                )
              : ListView.separated(
                  itemCount: response.items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final notification = response.items[index];

                    return _NotificationCard(
                      notification: notification,
                      isUpdating: updatingNotificationId == notification.id,
                      onMarkAsRead: () => onMarkAsRead(notification),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.isUpdating,
    required this.onMarkAsRead,
  });

  final AppNotification notification;
  final bool isUpdating;
  final VoidCallback onMarkAsRead;

  @override
  Widget build(BuildContext context) {
    final unread = notification.isUnread;
    final color = unread ? MusiHubColors.primary : MusiHubColors.textGrey;

    return Material(
      color: Colors.white,
      elevation: unread ? 4 : 1,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: unread && !isUpdating ? onMarkAsRead : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: unread
                  ? MusiHubColors.primary.withValues(alpha: 0.34)
                  : MusiHubColors.borderGrey,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_notificationIcon(notification.type), color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            notification.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        if (unread) const _UnreadDot(),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      notification.body,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatLocalDateTimeLabel(notification.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (unread) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: isUpdating ? null : onMarkAsRead,
                          icon: const Icon(Icons.done, size: 18),
                          label: Text(isUpdating ? 'Marcando...' : 'Leída'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  IconData _notificationIcon(String type) {
    return switch (type) {
      'alert_match' => Icons.notifications_active_outlined,
      'contact_request_received' => Icons.inbox_outlined,
      'contact_request_accepted' => Icons.mark_email_read_outlined,
      'contact_request_rejected' => Icons.block_outlined,
      _ => Icons.notifications_none,
    };
  }
}

class _SheetHandle extends StatelessWidget {
  const _SheetHandle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 42,
        height: 4,
        decoration: BoxDecoration(
          color: MusiHubColors.borderGrey,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 9,
      height: 9,
      margin: const EdgeInsets.only(left: 8, top: 5),
      decoration: const BoxDecoration(
        color: MusiHubColors.primary,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _NotificationsLoadError extends StatelessWidget {
  const _NotificationsLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('No se pudieron cargar las notificaciones.'),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
}
