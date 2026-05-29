import 'package:flutter/material.dart';
import 'package:musihub_front/core/catalog/catalog_item.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';
import 'package:musihub_front/core/forms/input_limits.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/core/widgets/location_selector.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';
import 'package:musihub_front/features/opportunities/opportunity_display.dart';

class OpportunityFilterData {
  const OpportunityFilterData({
    required this.types,
    required this.instruments,
    required this.styles,
    required this.locations,
  });

  final List<OpportunityType> types;
  final List<CatalogItem> instruments;
  final List<CatalogItem> styles;
  final List<LocationProvince> locations;
}

class OpportunitySearchPlaceholder extends StatelessWidget {
  const OpportunitySearchPlaceholder({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(2),
      child: Container(
        height: 39,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        color: MusiHubColors.fieldGrey,
        child: const Row(
          children: [
            Icon(Icons.search, size: 20, color: Color(0xFFB9B9B9)),
            SizedBox(width: 12),
            Text(
              'Buscar ...',
              style: TextStyle(color: Color(0xFF9B9B9B), fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class OpportunityQuickTypeFilters extends StatelessWidget {
  const OpportunityQuickTypeFilters({
    super.key,
    required this.types,
    required this.selectedTypeId,
    required this.onSelected,
  });

  final List<OpportunityType> types;
  final int? selectedTypeId;
  final ValueChanged<int?> onSelected;

  @override
  Widget build(BuildContext context) {
    final quickTypes = _orderedTypes(types);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _QuickFilterChip(
            label: 'Todos',
            selected: selectedTypeId == null,
            onTap: () => onSelected(null),
          ),
          for (final type in quickTypes) ...[
            const SizedBox(width: 12),
            _QuickFilterChip(
              label: opportunityTypeFilterLabel(type),
              selected: selectedTypeId == type.id,
              onTap: () => onSelected(type.id),
            ),
          ],
        ],
      ),
    );
  }

  List<OpportunityType> _orderedTypes(List<OpportunityType> types) {
    final orderedTypes = <OpportunityType>[];

    for (final code in opportunityTypeOrder) {
      for (final type in types) {
        if (type.code == code) {
          orderedTypes.add(type);
        }
      }
    }

    for (final type in types) {
      if (!opportunityTypeOrder.contains(type.code)) {
        orderedTypes.add(type);
      }
    }

    return orderedTypes;
  }
}

class _QuickFilterChip extends StatelessWidget {
  const _QuickFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      backgroundColor: selected
          ? MusiHubColors.primary
          : MusiHubColors.fieldGrey,
      labelStyle: TextStyle(
        color: selected ? Colors.white : Colors.black,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
    );
  }
}

class OpportunityFilterHeader extends StatelessWidget {
  const OpportunityFilterHeader({
    super.key,
    required this.expanded,
    required this.onTap,
  });

  final bool expanded;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          const Icon(
            Icons.filter_list,
            size: 18,
            color: MusiHubColors.textGrey,
          ),
          const SizedBox(width: 4),
          Text('Filtros', style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Icon(
            expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
            size: 18,
            color: MusiHubColors.textGrey,
          ),
        ],
      ),
    );
  }
}

class OpportunityAdvancedFilters extends StatelessWidget {
  const OpportunityAdvancedFilters({
    super.key,
    required this.data,
    required this.selectedTypeId,
    required this.selectedInstrumentId,
    required this.selectedStyleId,
    required this.cityController,
    required this.provinceController,
    required this.dateFromController,
    required this.dateToController,
    required this.minPriceController,
    required this.maxPriceController,
    required this.onTypeChanged,
    required this.onInstrumentChanged,
    required this.onStyleChanged,
    required this.onApply,
    required this.onClear,
  });

  final OpportunityFilterData data;
  final int? selectedTypeId;
  final int? selectedInstrumentId;
  final int? selectedStyleId;
  final TextEditingController cityController;
  final TextEditingController provinceController;
  final TextEditingController dateFromController;
  final TextEditingController dateToController;
  final TextEditingController minPriceController;
  final TextEditingController maxPriceController;
  final ValueChanged<int?> onTypeChanged;
  final ValueChanged<int?> onInstrumentChanged;
  final ValueChanged<int?> onStyleChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: MusiHubColors.borderGrey),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            DropdownButtonFormField<int>(
              key: ValueKey('type-$selectedTypeId'),
              initialValue: selectedTypeId,
              decoration: const InputDecoration(labelText: 'Tipo'),
              hint: const Text('Todos los tipos'),
              items: data.types
                  .map(
                    (type) => DropdownMenuItem<int>(
                      value: type.id,
                      child: Text(type.name),
                    ),
                  )
                  .toList(),
              onChanged: onTypeChanged,
            ),
            const SizedBox(height: 12),
            LocationSelector(
              locations: data.locations,
              provinceController: provinceController,
              cityController: cityController,
              requireProvince: false,
              requireCity: false,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('instrument-$selectedInstrumentId'),
              initialValue: selectedInstrumentId,
              decoration: const InputDecoration(labelText: 'Instrumento'),
              hint: const Text('Todos los instrumentos'),
              items: data.instruments
                  .map(
                    (instrument) => DropdownMenuItem<int>(
                      value: instrument.id,
                      child: Text(instrument.name),
                    ),
                  )
                  .toList(),
              onChanged: onInstrumentChanged,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              key: ValueKey('style-$selectedStyleId'),
              initialValue: selectedStyleId,
              decoration: const InputDecoration(labelText: 'Estilo'),
              hint: const Text('Todos los estilos'),
              items: data.styles
                  .map(
                    (style) => DropdownMenuItem<int>(
                      value: style.id,
                      child: Text(style.name),
                    ),
                  )
                  .toList(),
              onChanged: onStyleChanged,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateFromController,
              maxLength: InputLimits.date,
              inputFormatters: InputLimits.dateFormatters,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Fecha desde',
                helperText: 'Formato: YYYY-MM-DD',
                counterText: '',
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: dateToController,
              maxLength: InputLimits.date,
              inputFormatters: InputLimits.dateFormatters,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Fecha hasta',
                helperText: 'Formato: YYYY-MM-DD',
                counterText: '',
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: minPriceController,
              maxLength: InputLimits.price,
              inputFormatters: InputLimits.priceFormatters,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Precio minimo',
                counterText: '',
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: maxPriceController,
              maxLength: InputLimits.price,
              inputFormatters: InputLimits.priceFormatters,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                labelText: 'Precio maximo',
                counterText: '',
              ),
              onSubmitted: (_) => onApply(),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: onApply,
                    child: const Text('Aplicar'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: onClear,
                    child: const Text('Limpiar'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class OpportunityFilterLoading extends StatelessWidget {
  const OpportunityFilterLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Text('Cargando filtros...'),
      ],
    );
  }
}

class OpportunityFilterLoadError extends StatelessWidget {
  const OpportunityFilterLoadError({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'No se pudieron cargar los filtros.',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
        const SizedBox(height: 12),
        FilledButton(onPressed: onRetry, child: const Text('Reintentar')),
      ],
    );
  }
}

class OpportunityFeedResults extends StatelessWidget {
  const OpportunityFeedResults({
    super.key,
    required this.opportunities,
    required this.favoriteIds,
    required this.hasFilters,
    required this.onOpen,
    required this.onFavoriteTap,
    this.emptyMessage,
  });

  final List<Opportunity> opportunities;
  final Set<int> favoriteIds;
  final bool hasFilters;
  final ValueChanged<Opportunity> onOpen;
  final ValueChanged<Opportunity> onFavoriteTap;
  final String? emptyMessage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.center,
          child: Text(
            _resultLabel(opportunities.length),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 8),
        if (opportunities.isEmpty)
          _EmptyResults(
            message:
                emptyMessage ??
                (hasFilters
                    ? 'No hay anuncios para estos filtros.'
                    : 'No hay anuncios activos.'),
          )
        else
          for (var index = 0; index < opportunities.length; index++) ...[
            _OpportunityCard(
              opportunity: opportunities[index],
              isFavorite: favoriteIds.contains(opportunities[index].id),
              onTap: () => onOpen(opportunities[index]),
              onFavoriteTap: () => onFavoriteTap(opportunities[index]),
            ),
            if (index < opportunities.length - 1) const SizedBox(height: 14),
          ],
      ],
    );
  }

  String _resultLabel(int count) {
    if (count == 1) {
      return '1 Resultado';
    }

    return '$count Resultados';
  }
}

class _OpportunityCard extends StatelessWidget {
  const _OpportunityCard({
    required this.opportunity,
    required this.isFavorite,
    required this.onTap,
    required this.onFavoriteTap,
  });

  final Opportunity opportunity;
  final bool isFavorite;
  final VoidCallback onTap;
  final VoidCallback onFavoriteTap;

  @override
  Widget build(BuildContext context) {
    final isClosed = !opportunity.isActive;

    return Material(
      color: isClosed ? MusiHubColors.fieldGrey : Colors.white,
      elevation: isClosed ? 1 : 3,
      shadowColor: Colors.black.withValues(alpha: isClosed ? 0.08 : 0.18),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _OpportunityTags(opportunity: opportunity)),
                  if (isClosed) ...[
                    const SizedBox(width: 8),
                    const _ClosedBadge(),
                  ],
                  IconButton(
                    onPressed: onFavoriteTap,
                    icon: Icon(
                      isFavorite ? Icons.favorite : Icons.favorite_border,
                      color: isFavorite
                          ? isClosed
                                ? MusiHubColors.textGrey
                                : MusiHubColors.primary
                          : null,
                    ),
                    iconSize: 22,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: isFavorite ? 'Quitar de guardados' : 'Guardar',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                opportunity.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: isClosed ? MusiHubColors.textGrey : Colors.black,
                ),
              ),
              if (opportunity.authorBand != null) ...[
                const SizedBox(height: 3),
                Row(
                  children: [
                    const Icon(
                      Icons.groups_outlined,
                      size: 14,
                      color: MusiHubColors.primary,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        opportunity.authorBand!.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: MusiHubColors.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              Text(
                opportunity.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isClosed ? MusiHubColors.textGrey : null,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 14,
                runSpacing: 6,
                children: [
                  _MetaItem(
                    icon: Icons.location_on_outlined,
                    text: opportunity.city,
                  ),
                  if (opportunity.eventDate != null)
                    _MetaItem(
                      icon: Icons.calendar_month_outlined,
                      text: opportunityShortDateLabel(opportunity.eventDate!),
                    ),
                  if (opportunity.priceAmount != null)
                    _MetaItem(
                      icon: Icons.euro,
                      text: opportunityPriceLabel(opportunity.priceAmount!),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  const _EmptyResults({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      decoration: BoxDecoration(
        color: MusiHubColors.fieldGrey,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          const Icon(Icons.search_off, color: MusiHubColors.textGrey),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ClosedBadge extends StatelessWidget {
  const _ClosedBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: MusiHubColors.borderGrey),
      ),
      child: const Text(
        'Cerrado',
        style: TextStyle(
          color: MusiHubColors.textGrey,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
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
      if (opportunity.instruments.isNotEmpty)
        _TagData(label: opportunity.instruments.first.name),
      if (opportunity.styles.isNotEmpty)
        _TagData(label: opportunity.styles.first.name),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
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
      constraints: const BoxConstraints(minWidth: 68, maxWidth: 116),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
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
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 150),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

class OpportunityFeedBottomNav extends StatelessWidget {
  const OpportunityFeedBottomNav({
    super.key,
    this.selectedIndex = 0,
    required this.onHome,
    required this.onPublish,
    required this.onSaved,
    required this.onProfile,
  });

  final int selectedIndex;
  final VoidCallback onHome;
  final VoidCallback onPublish;
  final VoidCallback onSaved;
  final VoidCallback onProfile;

  @override
  Widget build(BuildContext context) {
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        switch (index) {
          case 0:
            onHome();
            return;
          case 1:
            onPublish();
            return;
          case 2:
            onSaved();
            return;
          case 3:
            onProfile();
            return;
        }
      },
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.home_outlined),
          selectedIcon: Icon(Icons.home),
          label: 'Inicio',
        ),
        NavigationDestination(
          icon: Icon(Icons.add_circle_outline),
          label: 'Publicar',
        ),
        NavigationDestination(
          icon: Icon(Icons.favorite_border),
          label: 'Guardados',
        ),
        NavigationDestination(
          icon: Icon(Icons.person_outline),
          label: 'Perfil',
        ),
      ],
    );
  }
}

class OpportunitiesLoadError extends StatelessWidget {
  const OpportunitiesLoadError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  final String message;
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
              message,
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
