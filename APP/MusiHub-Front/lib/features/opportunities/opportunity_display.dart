import 'package:flutter/material.dart';
import 'package:musihub_front/core/theme/musihub_theme.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';

const opportunityTypeOrder = [
  'clases',
  'bolos_sustituciones',
  'busqueda_miembros',
  'eventos',
  'compraventa',
];

String opportunityTypeFilterLabel(OpportunityType type) {
  switch (type.code) {
    case 'bolos_sustituciones':
      return 'Bolos';
    case 'busqueda_miembros':
      return 'Miembros';
    case 'compraventa':
      return 'Venta';
    default:
      return type.name;
  }
}

String opportunityTypeTagLabel(OpportunityType type) {
  switch (type.code) {
    case 'bolos_sustituciones':
      return 'Bolo';
    case 'busqueda_miembros':
      return 'Miembros';
    case 'compraventa':
      return 'Venta';
    default:
      return type.name;
  }
}

Color opportunityTypeTagColor(OpportunityType type) {
  switch (type.code) {
    case 'clases':
      return const Color(0xFFE4E5FF);
    case 'bolos_sustituciones':
      return const Color(0xFFFFFF9D);
    case 'busqueda_miembros':
      return const Color(0xFFDDF4E6);
    case 'eventos':
      return const Color(0xFFFFD7D7);
    case 'compraventa':
      return const Color(0xFFE0F0FF);
    default:
      return MusiHubColors.fieldGrey;
  }
}

Color opportunityTypeTagBorderColor(OpportunityType type) {
  switch (type.code) {
    case 'clases':
      return const Color(0xFFC7CBFF);
    case 'bolos_sustituciones':
      return const Color(0xFFE9DE78);
    case 'busqueda_miembros':
      return const Color(0xFFB9DFC8);
    case 'eventos':
      return const Color(0xFFF0B8B8);
    case 'compraventa':
      return const Color(0xFFB9D9EF);
    default:
      return MusiHubColors.borderGrey;
  }
}

String opportunityPriceLabel(String value) {
  final parsed = num.tryParse(value.replaceAll(',', '.'));

  if (parsed == null) {
    return '$value EUR';
  }

  final amount = parsed % 1 == 0
      ? parsed.toStringAsFixed(0)
      : parsed.toStringAsFixed(2);

  return '$amount EUR';
}

String opportunityShortDateLabel(String value) {
  final parts = _dateParts(value);

  if (parts == null) {
    return value;
  }

  return '${parts[2]}/${parts[1]}';
}

String opportunityLongDateLabel(String value) {
  final parts = _dateParts(value);

  if (parts == null) {
    return value;
  }

  final month = switch (parts[1]) {
    '01' => 'Ene',
    '02' => 'Feb',
    '03' => 'Mar',
    '04' => 'Abr',
    '05' => 'May',
    '06' => 'Jun',
    '07' => 'Jul',
    '08' => 'Ago',
    '09' => 'Sep',
    '10' => 'Oct',
    '11' => 'Nov',
    '12' => 'Dic',
    _ => parts[1],
  };

  return '${parts[2]} $month ${parts[0]}';
}

List<String>? _dateParts(String value) {
  final cleanValue = value.trim();
  final datePart = cleanValue.split(RegExp(r'[T\s]')).first;

  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(datePart)) {
    return null;
  }

  return datePart.split('-');
}
