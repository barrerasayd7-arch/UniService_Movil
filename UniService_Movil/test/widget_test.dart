import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app_uniservice/main.dart';

void main() {
  testWidgets('La app arranca en el login', (WidgetTester tester) async {
    await tester.pumpWidget(const UniServiceApp(rutaInicial: '/login'));
    await tester.pump();

    expect(find.text('Iniciar sesión'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('¿Olvidaste tu contraseña?'), findsOneWidget);
  });

  testWidgets('El login cabe sin desplazarse en un celular de 360x780', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const UniServiceApp(rutaInicial: '/login'));
    await tester.pump();

    final scroll = tester.state<ScrollableState>(find.byType(Scrollable).first);
    expect(scroll.position.maxScrollExtent, 0);
    expect(tester.takeException(), isNull);
  });
}
