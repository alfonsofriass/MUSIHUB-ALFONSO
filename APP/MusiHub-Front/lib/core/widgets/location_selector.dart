import 'package:flutter/material.dart';
import 'package:musihub_front/core/catalog/locations_api.dart';

class LocationSelector extends StatefulWidget {
  const LocationSelector({
    super.key,
    required this.locations,
    required this.provinceController,
    required this.cityController,
    this.provinceLabel = 'Provincia',
    this.cityLabel = 'Ciudad',
    this.requireProvince = true,
    this.requireCity = true,
  });

  final List<LocationProvince> locations;
  final TextEditingController provinceController;
  final TextEditingController cityController;
  final String provinceLabel;
  final String cityLabel;
  final bool requireProvince;
  final bool requireCity;

  @override
  State<LocationSelector> createState() => _LocationSelectorState();
}

class _LocationSelectorState extends State<LocationSelector> {
  String _selectedProvince = '';
  String _selectedCity = '';

  @override
  void initState() {
    super.initState();
    _syncFromControllers();
  }

  @override
  void didUpdateWidget(covariant LocationSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncFromControllers();
  }

  void _syncFromControllers() {
    final province = _validProvinceName(widget.provinceController.text);
    final city = _validCityName(province, widget.cityController.text);

    _selectedProvince = province;
    _selectedCity = city;

    if (widget.provinceController.text != province) {
      widget.provinceController.text = province;
    }

    if (widget.cityController.text != city) {
      widget.cityController.text = city;
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = _citiesForProvince(_selectedProvince);

    return Column(
      children: [
        DropdownButtonFormField<String>(
          key: ValueKey('province-$_selectedProvince'),
          initialValue: _selectedProvince.isEmpty ? null : _selectedProvince,
          decoration: InputDecoration(labelText: widget.provinceLabel),
          hint: Text(
            widget.requireProvince
                ? 'Selecciona provincia'
                : 'Todas las provincias',
          ),
          items: [
            if (!widget.requireProvince)
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Todas las provincias'),
              ),
            ...widget.locations.map(
              (province) => DropdownMenuItem<String>(
                value: province.name,
                child: Text(province.name),
              ),
            ),
          ],
          onChanged: (value) {
            final province = value ?? '';

            setState(() {
              _selectedProvince = province;
              _selectedCity = '';
              widget.provinceController.text = province;
              widget.cityController.clear();
            });
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey('city-$_selectedProvince-$_selectedCity'),
          initialValue: _selectedCity.isEmpty ? null : _selectedCity,
          decoration: InputDecoration(labelText: widget.cityLabel),
          hint: Text(widget.requireCity ? 'Selecciona ciudad' : 'Todas'),
          items: [
            if (!widget.requireCity)
              const DropdownMenuItem<String>(
                value: '',
                child: Text('Todas las ciudades'),
              ),
            ...cities.map(
              (city) => DropdownMenuItem<String>(
                value: city.name,
                child: Text(city.name),
              ),
            ),
          ],
          onChanged: _selectedProvince.isEmpty
              ? null
              : (value) {
                  final city = value ?? '';

                  setState(() {
                    _selectedCity = city;
                    widget.cityController.text = city;
                  });
                },
        ),
      ],
    );
  }

  String _validProvinceName(String value) {
    final trimmed = value.trim();

    for (final province in widget.locations) {
      if (province.name == trimmed) {
        return province.name;
      }
    }

    return '';
  }

  String _validCityName(String provinceName, String value) {
    final trimmed = value.trim();

    for (final city in _citiesForProvince(provinceName)) {
      if (city.name == trimmed) {
        return city.name;
      }
    }

    return '';
  }

  List<LocationCity> _citiesForProvince(String provinceName) {
    for (final province in widget.locations) {
      if (province.name == provinceName) {
        return province.cities;
      }
    }

    return const [];
  }
}
