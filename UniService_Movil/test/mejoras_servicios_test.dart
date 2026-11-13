import 'dart:async';
import 'dart:convert';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/perfil_repository.dart';
import 'package:app_uniservice/data/solicitudes_repository.dart';
import 'package:app_uniservice/screens/profile/profile_modals.dart';
import 'package:app_uniservice/screens/solicitudes/solicitudes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

Map<String, dynamic> fila(
  String estado,
  String titulo, {
  bool cliente = false,
}) => {
  'id_solicitud': estado == 'Pendiente' ? 1 : 2,
  'estado': estado,
  'rol': cliente ? 'cliente' : 'proveedor',
  'presupuesto': 20000,
  'servicio': {'id_servicio': 10, 'titulo': titulo, 'categoria': 'Tutorías'},
  'cliente': {'id_usuario': 1, 'nombre': 'Ana'},
  'proveedor': {'id_usuario': 2, 'nombre': 'Luis'},
};

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  Future<void> mostrar(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(useMaterial3: true), home: child),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Los filtros consultan la API y se conservan por bandeja', (
    tester,
  ) async {
    final peticiones = <Uri>[];
    final repo = SolicitudesRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          peticiones.add(r.url);
          final enviada = r.url.path.endsWith('enviadas');
          final estado = r.url.queryParameters['estado'];
          final filas = [
            fila(
              'Pendiente',
              enviada ? 'Enviada pendiente' : 'Recibida pendiente',
              cliente: enviada,
            ),
            fila(
              'Aceptada',
              enviada ? 'Enviada aceptada' : 'Recibida aceptada',
              cliente: enviada,
            ),
          ];
          return json(
            filas
                .where((f) => estado == null || f['estado'] == estado)
                .toList(),
          );
        }),
      ),
    );
    await mostrar(tester, SolicitudesScreen(repositorio: repo));
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Aceptadas'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Aceptadas'));
    await tester.pumpAndSettle();
    expect(peticiones.last.path, '/api/solicitudes/recibidas');
    expect(peticiones.last.queryParameters, {'estado': 'Aceptada'});
    expect(find.text('Recibida aceptada'), findsOneWidget);
    expect(find.text('Recibida pendiente'), findsNothing);
    await tester.tap(find.text('Enviadas'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Todas'))
          .selected,
      isTrue,
    );
    await tester.tap(find.widgetWithText(ChoiceChip, 'Pendientes'));
    await tester.pumpAndSettle();
    expect(peticiones.last.path, '/api/solicitudes/enviadas');
    expect(peticiones.last.queryParameters, {'estado': 'Pendiente'});
    expect(find.text('Enviada aceptada'), findsNothing);
    await tester.tap(find.text('Recibidas'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Aceptadas'))
          .selected,
      isTrue,
    );
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Completadas'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Completadas'));
    await tester.pumpAndSettle();
    expect(find.text('No hay solicitudes completadas'), findsOneWidget);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Todas'));
    await tester.pumpAndSettle();
    expect(peticiones.last.queryParameters, isEmpty);
    expect(find.text('Recibida pendiente'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Una respuesta tardía no sustituye el filtro actual y un error permite reintentar',
    (tester) async {
      final atrasada = Completer<http.Response>();
      var fallar = true;
      final repo = SolicitudesRepository(
        ApiClient(
          baseUrl: 'http://api.test',
          client: MockClient((r) async {
            final estado = r.url.queryParameters['estado'];
            if (estado == 'Pendiente') return atrasada.future;
            if (estado == 'Aceptada') {
              return fallar
                  ? json({'error': 'Fallo temporal'}, 500)
                  : json([fila('Aceptada', 'Resultado correcto')]);
            }
            return json([]);
          }),
        ),
      );
      await mostrar(tester, SolicitudesScreen(repositorio: repo));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Pendientes'));
      await tester.pump();
      await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Aceptadas'));
      await tester.tap(find.widgetWithText(ChoiceChip, 'Aceptadas'));
      await tester.pumpAndSettle();
      expect(find.text('Fallo temporal'), findsOneWidget);
      fallar = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      atrasada.complete(json([fila('Pendiente', 'Resultado antiguo')]));
      await tester.pumpAndSettle();
      expect(find.text('Resultado correcto'), findsOneWidget);
      expect(find.text('Resultado antiguo'), findsNothing);
    },
  );

  Future<void> abrirReporte(
    WidgetTester tester,
    PerfilRepository repo, {
    int? servicio,
    int? usuario,
  }) async {
    await mostrar(
      tester,
      Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => mostrarReportar(
              context,
              idServicio: servicio,
              tituloServicio: servicio == null ? null : 'Tutoría de cálculo',
              idUsuario: usuario,
              nombreUsuario: usuario == null ? null : 'Luis',
              repositorio: repo,
            ),
            child: const Text('Abrir reporte'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Abrir reporte'));
    await tester.pumpAndSettle();
  }

  Future<void> llenarReporte(WidgetTester tester) async {
    await tester.enterText(
      find.byType(TextField).at(0),
      '  Información falsa  ',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      '  El servicio publicado contiene información engañosa.  ',
    );
    await tester.ensureVisible(find.text('Enviar reporte'));
  }

  testWidgets(
    'Reportar servicio valida y envía el motivo y el servicio correcto',
    (tester) async {
      final peticiones = <http.Request>[];
      final repo = PerfilRepository(
        ApiClient(
          baseUrl: 'http://api.test',
          client: MockClient((r) async {
            peticiones.add(r);
            return json({'id_reporte': 1});
          }),
        ),
      );
      await abrirReporte(tester, repo, servicio: 69);
      expect(find.text('Tutoría de cálculo'), findsOneWidget);
      expect(find.text('Servicio inapropiado'), findsOneWidget);
      expect(find.text('Acoso'), findsNothing);
      await tester.ensureVisible(find.text('Enviar reporte'));
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(peticiones, isEmpty);
      // El aviso de validación se cierra antes de completar el formulario.
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      await llenarReporte(tester);
      await tester.tap(find.text('Enviar reporte'));
      await tester.pumpAndSettle();
      expect(peticiones.single.url.path, '/api/reportes');
      expect(peticiones.single.method, 'POST');
      expect(jsonDecode(peticiones.single.body), {
        'tipo_reporte': 'servicio_fraude',
        'id_servicio': 69,
        'titulo': 'Información falsa',
        'descripcion': 'El servicio publicado contiene información engañosa.',
      });
      await tester.tap(find.text('Entendido'));
      await tester.pumpAndSettle();
      expect(find.text('Reportar servicio'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Un reporte duplicado muestra el error y conserva el texto', (
    tester,
  ) async {
    final repo = PerfilRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient(
          (r) async =>
              json({'error': 'Ya tienes un reporte igual en revisión'}, 409),
        ),
      ),
    );
    await abrirReporte(tester, repo, servicio: 69);
    await llenarReporte(tester);
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();
    expect(find.text('Ya tienes un reporte igual en revisión'), findsOneWidget);
    expect(find.text('Reportar servicio'), findsOneWidget);
    expect(
      tester
          .widget<TextField>(find.byType(TextField).first)
          .controller!
          .text
          .trim(),
      'Información falsa',
    );
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  });

  testWidgets('Reportar un usuario conserva sus motivos y su referencia', (
    tester,
  ) async {
    late Map<String, dynamic> enviado;
    final repo = PerfilRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          enviado = jsonDecode(r.body) as Map<String, dynamic>;
          return json({'id_reporte': 2});
        }),
      ),
    );
    await abrirReporte(tester, repo, usuario: 12);
    expect(find.text('Acoso'), findsOneWidget);
    expect(find.text('Servicio inapropiado'), findsNothing);
    await llenarReporte(tester);
    await tester.tap(find.text('Enviar reporte'));
    await tester.pumpAndSettle();
    expect(enviado['id_usuario_reportado'], 12);
    expect(enviado['tipo_reporte'], 'usuario_acoso');
    expect(enviado.containsKey('id_servicio'), isFalse);
    await tester.tap(find.text('Entendido'));
    await tester.pumpAndSettle();
  });
}
