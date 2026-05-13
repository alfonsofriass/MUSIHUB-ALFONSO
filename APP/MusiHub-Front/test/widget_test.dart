import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:musihub_front/features/auth/login_screen.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('MusiHub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Crear cuenta'), findsOneWidget);
  });
}
