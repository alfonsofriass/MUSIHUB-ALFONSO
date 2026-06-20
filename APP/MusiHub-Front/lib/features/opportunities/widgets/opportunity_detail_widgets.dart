import 'package:flutter/material.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/contact_action_tile.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';

class OpportunityDetailContent extends StatelessWidget {
  const OpportunityDetailContent({
    super.key,
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
        Text('Descripción', style: Theme.of(context).textTheme.titleMedium),
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
        borderColor: opportunityTypeTagBorderColor(opportunity.type),
        isType: true,
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
  const _TagData({
    required this.label,
    this.color = Colors.white,
    this.borderColor = MusiHubColors.borderGrey,
    this.isType = false,
  });

  final String label;
  final Color color;
  final Color borderColor;
  final bool isType;
}

class _SmallTag extends StatelessWidget {
  const _SmallTag({required this.tag});

  final _TagData tag;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 72, maxWidth: 142),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: tag.color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: tag.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (tag.isType) ...[
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: tag.borderColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Flexible(
            child: Text(
              tag.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ],
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

    return parts.isEmpty ? 'Sin ubicación' : parts.join(', ');
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
        color: MusiHubColors.fieldGrey.withValues(alpha: 0.55),
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
        opportunity.authorUser?.fullName ?? 'Autor del anuncio';

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
      color: MusiHubColors.fieldGrey,
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            border: Border.all(color: MusiHubColors.borderGrey),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: MusiHubColors.primary.withValues(alpha: 0.18),
                child: Icon(icon, size: 18, color: MusiHubColors.primary),
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
                      style: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: MusiHubColors.textGrey,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
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
      return ContactActionTile(
        method: opportunity.contactMethod,
        value: contactValue,
      );
    }

    if (!opportunity.isActive) {
      return const _ContactNotice(
        icon: Icons.lock_outline,
        text: 'Este anuncio está cerrado y ya no acepta solicitudes.',
      );
    }

    if (isOwnOpportunity) {
      return const _ContactNotice(
        icon: Icons.lock_outline,
        text: 'Tu dato de contacto no está visible públicamente.',
      );
    }

    if (contactRequestStatus == 'pending') {
      return const _ContactStateNotice(
        icon: Icons.mark_email_unread_outlined,
        text: 'Solicitud enviada',
        detail: 'El anunciante todavía no ha respondido.',
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
        detail: 'El contacto todavía no está disponible.',
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

class OpportunityLoadError extends StatelessWidget {
  const OpportunityLoadError({super.key, required this.onRetry});

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
