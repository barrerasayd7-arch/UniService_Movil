import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/servicios_repository.dart';
import 'package:app_uniservice/screens/service_detail/detail_screen.dart';

import 'fakes/api_falsa.dart';

/// Detalle servido por una API falsa que responde [status] con [cuerpo].
Widget _detalle(int status, Object cuerpo) {
  final repo = ServiciosRepository(
    ApiClient(
      baseUrl: 'http://api.test',
      client: MockClient(
        (_) async => http.Response(
          jsonEncode(cuerpo),
          status,
          headers: {'content-type': 'application/json; charset=utf-8'},
        ),
      ),
    ),
  );
  return MaterialApp(home: DetailScreen(idServicio: 69, repositorio: repo));
}

void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.instance.platformDispatcher.views.first;
    view.physicalSize = const Size(390, 844);
    view.devicePixelRatio = 1;
  });
  tearDown(() => TestWidgetsFlutterBinding.instance.platformDispatcher.views.first.reset());

  testWidgets('Un invitado ve el servicio, pero no el contacto ni el formulario', (tester) async {
    await tester.pumpWidget(_detalle(200, detalleInvitado()));
    await tester.pumpAndSettle();

    expect(find.text('Pensión cerca de la UPC'), findsOneWidget);
    expect(find.text('\$450.000 COP'), findsOneWidget);
    expect(find.text('Precio por mes'), findsOneWidget);
    expect(find.text('¿Te interesa este servicio?'), findsOneWidget);
    expect(find.text('Inicia sesión para ver la ubicación.'), findsOneWidget);
    expect(find.textContaining('Contactar por'), findsNothing);
    expect(find.text('Enviar solicitud'), findsNothing);
    expect(find.text('Reportar'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Un servicio que no existe muestra "no encontrado"', (tester) async {
    await tester.pumpWidget(_detalle(404, {'error': 'Servicio no encontrado'}));
    await tester.pumpAndSettle();
    expect(find.text('Servicio no encontrado'), findsOneWidget);
  });

  testWidgets('Un error del servidor permite reintentar', (tester) async {
    await tester.pumpWidget(_detalle(500, {'error': 'Error interno del servidor'}));
    await tester.pumpAndSettle();
    expect(find.text('No pudimos cargar el servicio'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });
}
