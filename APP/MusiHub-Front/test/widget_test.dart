import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:musihub_front/features/auth/login_screen.dart';
import 'package:musihub_front/features/opportunities/opportunities_api.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('MusiHub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });

  test('builds opportunity filter query params', () {
    const filters = OpportunityFilters(
      typeId: 1,
      city: ' Granada ',
      province: '',
      instrumentId: 2,
      styleId: 1,
      dateFrom: '2026-06-01',
      dateTo: '2026-06-30',
      minPrice: 10,
      maxPrice: 30,
    );

    expect(filters.toQueryParameters(), {
      'type_id': '1',
      'city': 'Granada',
      'instrument_id': '2',
      'style_id': '1',
      'date_from': '2026-06-01',
      'date_to': '2026-06-30',
      'min_price': '10',
      'max_price': '30',
    });
  });
}
