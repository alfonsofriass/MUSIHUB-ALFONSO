import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ContactActionTile extends StatelessWidget {
  const ContactActionTile({
    super.key,
    required this.method,
    required this.value,
    this.title,
    this.subtitle,
    this.trailingIcon,
    this.onTap,
  });

  final String method;
  final String value;
  final String? title;
  final String? subtitle;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap:
            onTap ??
            () => openContactAction(context, method: method, value: value),
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
                child: Icon(_contactIcon(method), color: MusiHubColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title ?? _contactLabel(method),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle ?? value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              Icon(
                trailingIcon ?? Icons.open_in_new,
                color: MusiHubColors.textGrey,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> openContactAction(
  BuildContext context, {
  required String method,
  required String value,
}) async {
  final trimmedValue = value.trim();

  if (trimmedValue.isEmpty) {
    return;
  }

  final uri = _contactUri(method, trimmedValue);
  if (uri != null) {
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (launched) {
        return;
      }
    } catch (_) {
      // Si el sistema no puede abrir la app externa, dejamos copiar el dato.
    }
  }

  await Clipboard.setData(ClipboardData(text: trimmedValue));
  if (context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Contacto copiado.')));
  }
}

Uri? _contactUri(String method, String value) {
  switch (method) {
    case 'email':
      return Uri(scheme: 'mailto', path: value);
    case 'phone':
      return Uri(scheme: 'tel', path: value);
    case 'whatsapp':
      final phone = value.replaceAll(RegExp(r'[^0-9]'), '');
      return phone.isEmpty ? null : Uri.parse('https://wa.me/$phone');
    case 'website':
      return _webUri(value);
    default:
      return null;
  }
}

Uri? _webUri(String value) {
  final normalizedValue = value.contains('://') ? value : 'https://$value';
  final uri = Uri.tryParse(normalizedValue);

  if (uri == null || !uri.hasScheme) {
    return null;
  }

  if (uri.scheme != 'http' && uri.scheme != 'https') {
    return null;
  }

  return uri;
}

String _contactLabel(String method) {
  switch (method) {
    case 'whatsapp':
      return 'WhatsApp';
    case 'email':
      return 'Email';
    case 'phone':
      return 'Teléfono';
    case 'website':
      return 'Enlace personal';
    default:
      return 'Contacto';
  }
}

IconData _contactIcon(String method) {
  switch (method) {
    case 'whatsapp':
      return Icons.chat_outlined;
    case 'email':
      return Icons.mail_outline;
    case 'phone':
      return Icons.phone_outlined;
    case 'website':
      return Icons.link_outlined;
    default:
      return Icons.contact_page_outlined;
  }
}
