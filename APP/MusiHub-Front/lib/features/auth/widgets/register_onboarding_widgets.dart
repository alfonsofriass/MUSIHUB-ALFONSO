part of '../register_screen.dart';

class _StepList extends StatelessWidget {
  const _StepList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 32),
      children: children,
    );
  }
}

class _StepProgress extends StatelessWidget {
  const _StepProgress({required this.currentStep});

  final int currentStep;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Paso $currentStep de 3',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 1; index <= 3; index++) ...[
              Expanded(
                child: Container(
                  height: 5,
                  decoration: BoxDecoration(
                    color: index <= currentStep
                        ? MusiHubColors.primary
                        : MusiHubColors.borderGrey,
                    borderRadius: BorderRadius.circular(30),
                  ),
                ),
              ),
              if (index < 3) const SizedBox(width: 8),
            ],
          ],
        ),
      ],
    );
  }
}

class _LabeledField extends StatelessWidget {
  const _LabeledField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.role,
    required this.selected,
    required this.onTap,
  });

  final _RoleOption role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected
                  ? MusiHubColors.primary
                  : MusiHubColors.borderGrey,
              width: selected ? 1.4 : 1,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 10,
                offset: const Offset(0, 3),
                color: Colors.black.withValues(alpha: 0.12),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: selected
                      ? MusiHubColors.primary.withValues(alpha: 0.14)
                      : MusiHubColors.fieldGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(role.icon, color: Colors.black),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      role.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      role.subtitle,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (selected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: MusiHubColors.primary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChipSection extends StatelessWidget {
  const _ChipSection({
    required this.title,
    this.subtitle,
    required this.items,
    required this.selectedIds,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final List<CatalogItem> items;
  final Set<int> selectedIds;
  final ValueChanged<CatalogItem> onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
        ],
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _SelectableChip(
                label: item.name,
                selected: selectedIds.contains(item.id),
                onTap: () => onTap(item),
              ),
          ],
        ),
      ],
    );
  }
}

class _SelectableChip extends StatelessWidget {
  const _SelectableChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: MusiHubColors.primary,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: selected ? MusiHubColors.primary : MusiHubColors.borderGrey,
      ),
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontWeight: FontWeight.w600,
      ),
      onSelected: (_) => onTap(),
    );
  }
}

class _AlertActivationTile extends StatelessWidget {
  const _AlertActivationTile({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: MusiHubColors.primary.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.notifications_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alertas activas',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 3),
                Text(
                  'Recibiras avisos segun tus preferencias',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Switch(value: enabled, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _OpportunityTypeTile extends StatelessWidget {
  const _OpportunityTypeTile({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final OpportunityType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: _cardDecoration(
          borderColor: selected
              ? MusiHubColors.primary
              : MusiHubColors.borderGrey,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type.name,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _opportunityTypeSubtitle(type.code),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            Switch(value: selected, onChanged: (_) => onTap()),
          ],
        ),
      ),
    );
  }

  String _opportunityTypeSubtitle(String code) {
    return switch (code) {
      'clases' => 'Clases, talleres y formacion',
      'bolos_sustituciones' => 'Bolos y sustituciones musicales',
      'busqueda_miembros' => 'Bandas que buscan miembros',
      'eventos' => 'Eventos y oportunidades musicales',
      'compraventa' => 'Venta o compra de equipo',
      _ => 'Oportunidades de MusiHub',
    };
  }
}

class _PrivacyConsentCard extends StatelessWidget {
  const _PrivacyConsentCard({
    required this.accepted,
    required this.onChanged,
    required this.onOpenPrivacy,
  });

  final bool accepted;
  final ValueChanged<bool> onChanged;
  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 12, 14, 12),
      decoration: _cardDecoration(
        borderColor: accepted
            ? MusiHubColors.primary
            : MusiHubColors.borderGrey,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: accepted,
            onChanged: (value) => onChanged(value ?? false),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Acepto los terminos y la politica de privacidad',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 4),
                Text(
                  'MusiHub usara tus datos para crear tu cuenta, perfil, anuncios, bandas, favoritos, alertas y solicitudes de contacto.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: onOpenPrivacy,
                    child: const Text('Ver informacion sobre privacidad'),
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

class _PrivacyInfoSheet extends StatelessWidget {
  const _PrivacyInfoSheet();

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * 0.86;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            Row(
              children: [
                const Icon(
                  Icons.privacy_tip_outlined,
                  color: MusiHubColors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Privacidad y datos',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'MusiHub utiliza tus datos para ofrecer las funciones principales de la app y mostrar informacion musical relevante a otros usuarios.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            const _PrivacyInfoSection(
              title: 'Datos que usamos',
              items: [
                'Nombre, email y rol de usuario.',
                'Ciudad, provincia, instrumentos, estilos y biografia.',
                'Bandas, anuncios, favoritos, alertas y solicitudes de contacto.',
                'Token del dispositivo para notificaciones push si activas alertas.',
              ],
            ),
            const _PrivacyInfoSection(
              title: 'Visibilidad',
              items: [
                'Tu perfil publico puede mostrar nombre, ubicacion, instrumentos, estilos y bandas visibles.',
                'Tus datos de contacto no se muestran publicamente.',
                'El contacto de anuncios se comparte solo si aceptas una solicitud.',
              ],
            ),
            const _PrivacyInfoSection(
              title: 'Uso de los datos',
              items: [
                'No usamos tus datos para publicidad.',
                'No vendemos tus datos a terceros.',
                'Puedes cerrar sesion y solicitar la modificacion o eliminacion de tus datos.',
              ],
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyInfoSection extends StatelessWidget {
  const _PrivacyInfoSection({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final item in items) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('- '),
                Expanded(
                  child: Text(
                    item,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
          ],
        ],
      ),
    );
  }
}

class _LoginFooter extends StatelessWidget {
  const _LoginFooter({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 22),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Ya tienes cuenta?',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          TextButton(onPressed: onTap, child: const Text('Inicia sesion')),
        ],
      ),
    );
  }
}

class _StepError extends StatelessWidget {
  const _StepError({required this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    final message = this.message;

    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        message,
        style: TextStyle(
          color: Theme.of(context).colorScheme.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _CatalogLoadError extends StatelessWidget {
  const _CatalogLoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'No se pudieron cargar los catalogos.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration({Color borderColor = MusiHubColors.borderGrey}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: borderColor),
    boxShadow: [
      BoxShadow(
        blurRadius: 10,
        offset: const Offset(0, 3),
        color: Colors.black.withValues(alpha: 0.12),
      ),
    ],
  );
}
