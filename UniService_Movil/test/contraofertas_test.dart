import 'dart:convert';
import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/solicitudes_repository.dart';
import 'package:app_uniservice/models/solicitud.dart';
import 'package:app_uniservice/screens/chat/chat_session.dart';
import 'package:app_uniservice/screens/solicitudes/solicitudes_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> solicitud({bool cliente = false, String? oferta}) => {
  'id_solicitud': 40,
  'estado': 'Pendiente',
  'rol': cliente ? 'cliente' : 'proveedor',
  'presupuesto': 40000,
  'contraoferta': oferta == null ? null : 50000,
  'estado_contraoferta': oferta,
  'version_contraoferta': oferta == null ? 0 : 1,
  'servicio': {'id_servicio': 10, 'titulo': 'Tutoría', 'categoria': 'Tutorías'},
  'cliente': {'id_usuario': 1, 'nombre': 'Ana'},
  'proveedor': {'id_usuario': 2, 'nombre': 'Luis'},
};
http.Response json(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'El precio aprobado requiere confirmación y conserva el presupuesto',
    () {
      final inicial = Solicitud.fromJson(solicitud());
      expect(inicial.puedeAceptar && inicial.puedeContraofertar, isTrue);
      final pendiente = Solicitud.fromJson(solicitud(oferta: 'pendiente'));
      expect(pendiente.puedeAceptar || pendiente.puedeContraofertar, isFalse);
      final aceptada = Solicitud.fromJson(solicitud(oferta: 'aceptada'));
      expect(aceptada.estado, 'Pendiente');
      expect(aceptada.puedeAceptar, isTrue);
      expect(aceptada.puedeCompletar, isFalse);
      expect(aceptada.precioAcordado, 50000);
      expect(aceptada.presupuesto, 40000);
      final rechazada = Solicitud.fromJson(solicitud(oferta: 'rechazada'));
      expect(rechazada.precioAcordado, 40000);
      expect(rechazada.puedeAceptar && rechazada.puedeContraofertar, isTrue);
      for (final estado in [
        'Aceptada',
        'Cancelada',
        'Completada',
        'Rechazada',
      ]) {
        for (final cliente in [true, false]) {
          final s = Solicitud.fromJson(
            solicitud(cliente: cliente, oferta: 'pendiente')
              ..['estado'] = estado,
          );
          expect(
            s.puedeAceptar ||
                s.puedeContraofertar ||
                s.puedeResponderContraoferta,
            isFalse,
          );
        }
      }
    },
  );

  Future<SolicitudesRepository> mostrar(
    WidgetTester tester,
    Map<String, dynamic> fila,
    Future<http.Response> Function(http.Request) post,
  ) async {
    final cliente = fila['rol'] == 'cliente';
    final repo = SolicitudesRepository(
      ApiClient(
        baseUrl: 'http://api.test',
        client: MockClient((r) async {
          if (r.method == 'POST') return post(r);
          return json(
            r.url.path.endsWith(cliente ? 'enviadas' : 'recibidas')
                ? [fila]
                : [],
          );
        }),
      ),
    );
    tester.view.physicalSize = const Size(360, 850);
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      repo.cambios.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark(useMaterial3: true),
        navigatorObservers: [chatRouteObserver],
        home: SolicitudesScreen(
          repositorio: repo,
          pestanaInicial: cliente ? 1 : 0,
        ),
      ),
    );
    await tester.pumpAndSettle();
    return repo;
  }

  Future<void> pulsar(WidgetTester tester, Finder boton) async {
    await tester.ensureVisible(boton);
    await tester.tap(boton);
    await tester.pumpAndSettle();
  }

  testWidgets('Aceptar usa presupuesto original sin campo de precio', (
    tester,
  ) async {
    final fila = solicitud();
    final peticiones = <http.Request>[];
    await mostrar(tester, fila, (r) async {
      peticiones.add(r);
      fila['estado'] = 'Aceptada';
      return json({});
    });
    for (final boton in ['Chatear', 'Rechazar', 'Aceptar', 'Contraoferta']) {
      expect(find.text(boton), findsOneWidget);
    }
    await pulsar(tester, find.text('Aceptar'));
    expect(find.byType(TextField), findsNothing);
    expect(find.textContaining('presupuesto del cliente'), findsOneWidget);
    await pulsar(tester, find.widgetWithText(TextButton, 'Aceptar'));
    expect(peticiones.single.url.path, '/api/solicitudes/40/aceptar');
    expect(jsonDecode(peticiones.single.body), {'version_contraoferta': 0});
    await pulsar(tester, find.text('Entendido'));
    expect(find.text('Marcar como completada'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Contraoferta valida precio y espera al cliente sin aceptar', (
    tester,
  ) async {
    final fila = solicitud();
    final peticiones = <http.Request>[];
    await mostrar(tester, fila, (r) async {
      peticiones.add(r);
      fila.addAll({
        'contraoferta': 50000,
        'estado_contraoferta': 'pendiente',
        'version_contraoferta': 1,
      });
      return json({});
    });
    await pulsar(tester, find.text('Contraoferta'));
    final enviar = find.widgetWithText(TextButton, 'Enviar contraoferta');
    await pulsar(tester, enviar);
    expect(find.text('Ingresa un precio entre 1 y 99.999.999'), findsOneWidget);
    expect(peticiones, isEmpty);
    await tester.enterText(find.byType(TextField), '0');
    await pulsar(tester, enviar);
    expect(peticiones, isEmpty);
    await tester.enterText(find.byType(TextField), '50000');
    await pulsar(tester, enviar);
    expect(peticiones.single.url.path, '/api/solicitudes/40/contraoferta');
    expect(jsonDecode(peticiones.single.body), {
      'precio': 50000,
      'version_contraoferta': 0,
    });
    await pulsar(tester, find.text('Entendido'));
    expect(find.text('Aceptar'), findsNothing);
    expect(
      find.text('Contraoferta enviada. Esperando la respuesta del cliente.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('El cliente acepta el precio, pero el servicio sigue pendiente', (
    tester,
  ) async {
    final fila = solicitud(cliente: true, oferta: 'pendiente');
    final peticiones = <http.Request>[];
    await mostrar(tester, fila, (r) async {
      peticiones.add(r);
      fila['estado_contraoferta'] = 'aceptada';
      return json({});
    });
    await pulsar(tester, find.text('Aceptar contraoferta'));
    await pulsar(tester, find.text('Aceptar precio'));
    expect(
      peticiones.single.url.path,
      '/api/solicitudes/40/aceptar-contraoferta',
    );
    expect(jsonDecode(peticiones.single.body), {'version_contraoferta': 1});
    await pulsar(tester, find.text('Entendido'));
    expect(
      find.text(
        'Aceptaste la contraoferta. Falta que el proveedor confirme el servicio.',
      ),
      findsOneWidget,
    );
    expect(find.text('Aceptar contraoferta'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'La respuesta del cliente habilita la confirmación del proveedor',
    (tester) async {
      final fila = solicitud(oferta: 'pendiente');
      final peticiones = <http.Request>[];
      final repo = await mostrar(tester, fila, (r) async {
        peticiones.add(r);
        fila['estado'] = 'Aceptada';
        return json({});
      });
      expect(find.text('Aceptar'), findsNothing);
      fila['estado_contraoferta'] = 'aceptada';
      repo.avisarCambio();
      await tester.pumpAndSettle();
      await pulsar(tester, find.text('Aceptar'));
      expect(
        find.textContaining('precio que el cliente aceptó'),
        findsOneWidget,
      );
      await pulsar(tester, find.widgetWithText(TextButton, 'Aceptar'));
      expect(jsonDecode(peticiones.single.body), {'version_contraoferta': 1});
      await pulsar(tester, find.text('Entendido'));
      expect(find.text('Marcar como completada'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Rechazar precio conserva la solicitud y el presupuesto original',
    (tester) async {
      final fila = solicitud(cliente: true, oferta: 'pendiente');
      final peticiones = <http.Request>[];
      await mostrar(tester, fila, (r) async {
        peticiones.add(r);
        fila['estado_contraoferta'] = 'rechazada';
        return json({});
      });
      await pulsar(tester, find.text('Rechazar contraoferta'));
      await pulsar(tester, find.text('Rechazar precio'));
      expect(
        peticiones.single.url.path,
        '/api/solicitudes/40/rechazar-contraoferta',
      );
      await pulsar(tester, find.text('Entendido'));
      expect(
        find.text(
          'Rechazaste la contraoferta. Tu presupuesto original sigue vigente.',
        ),
        findsOneWidget,
      );
      expect(Solicitud.fromJson(fila).precioAcordado, 40000);
    },
  );

  testWidgets('Un conflicto informa el error y recarga la solicitud', (
    tester,
  ) async {
    final fila = solicitud(oferta: 'aceptada');
    await mostrar(tester, fila, (_) async {
      fila['estado'] = 'Cancelada';
      return json({
        'error': 'La solicitud cambió. Actualiza la bandeja antes de continuar',
      }, 409);
    });
    await pulsar(tester, find.text('Aceptar'));
    await pulsar(tester, find.widgetWithText(TextButton, 'Aceptar'));
    expect(
      find.text('La solicitud cambió. Actualiza la bandeja antes de continuar'),
      findsOneWidget,
    );
    await pulsar(tester, find.text('Entendido'));
    expect(find.text('Aceptar'), findsNothing);
    expect(find.text('Marcar como completada'), findsNothing);
    expect(find.text('Cancelada'), findsOneWidget);
  });
}
