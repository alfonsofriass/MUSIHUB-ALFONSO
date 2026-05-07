import 'package:flutter_test/flutter_test.dart';

import 'package:musihub_front/main.dart';

void main() {
  testWidgets('shows login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MusiHubApp());

    expect(find.text('MusiHub'), findsOneWidget);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Contrasena'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });
}
