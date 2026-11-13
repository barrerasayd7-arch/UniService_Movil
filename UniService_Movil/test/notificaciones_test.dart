import 'dart:async';
import 'dart:convert';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/notificaciones_controller.dart';
import 'package:app_uniservice/models/auth_user.dart';
import 'package:app_uniservice/screens/chat/chat_session.dart';
import 'package:app_uniservice/screens/home/botones_flotantes.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

class MemoriaAvisos extends NotificacionesStore {
  final datos = <int, String>{};
  bool fallar = false;
  @override
  Future<String?> leer(int usuario) async => datos[usuario];
  @override
  Future<void> guardar(int usuario, String valor) async {
    if (fallar) throw StateError('Almacenamiento no disponible');
    datos[usuario] = valor;
  }
}

Map<String, dynamic> aviso(
  String id, {
  String texto = 'Ana solicitó tu servicio',
  String destino = 'solicitudes',
  int argumento = 0,
}) => {
  'id': id,
  'texto': texto,
  'fecha': '2026-11-13T15:00:00Z',
  'destino': destino,
  'argumento': argumento,
};
http.Response respuesta(Object data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
NotificacionesController controlador(
  Future<http.Response> Function(http.Request) handler, [
  MemoriaAvisos? memoria,
]) => NotificacionesController(
  api: ApiClient(baseUrl: 'http://api.test', client: MockClient(handler)),
  store: memoria ?? MemoriaAvisos(),
);

void main() {
  setUp(() => GoogleFonts.config.allowRuntimeFetching = false);

  test(
    'Lectura y descarte sobreviven al reinicio y se separan por cuenta',
    () async {
      final memoria = MemoriaAvisos();
      var lista = [aviso('pendiente')];
      Future<http.Response> api(http.Request r) async {
        expect(r.url.path, '/api/notificaciones');
        return respuesta(lista);
      }

      final uno = controlador(api, memoria);
      await uno.cambiarUsuario(1);
      expect(uno.noLeidas, 1);
      await uno.leer(uno.avisos.single);
      await uno.actualizar();
      expect(uno.noLeidas, 0);
      uno.dispose();
      final dos = controlador(api, memoria);
      await dos.cambiarUsuario(1);
      expect(dos.noLeidas, 0);
      await dos.vaciar();
      await dos.actualizar();
      expect(dos.avisos, isEmpty);
      dos.dispose();
      final tres = controlador(api, memoria);
      await tres.cambiarUsuario(1);
      expect(tres.avisos, isEmpty);
      lista = [aviso('aceptada')];
      await tres.actualizar();
      expect(tres.noLeidas, 1);
      await tres.leerTodas();
      await tres.cambiarUsuario(2);
      expect(tres.noLeidas, 1);
      await tres.cambiarUsuario(null);
      expect(tres.avisos, isEmpty);
      expect(tres.noLeidas, 0);
      tres.dispose();
    },
  );

  test(
    'Una respuesta de la cuenta anterior nunca llega a la nueva sesión',
    () async {
      final antigua = Completer<http.Response>();
      final iniciado = Completer<void>();
      var llamadas = 0;
      final c = controlador((_) async {
        if (++llamadas == 1) {
          iniciado.complete();
          return antigua.future;
        }
        return respuesta([aviso('cuenta2', texto: 'Aviso de Luis')]);
      });
      final cargaAnterior = c.cambiarUsuario(1);
      await iniciado.future;
      await c.cambiarUsuario(2);
      antigua.complete(respuesta([aviso('cuenta1', texto: 'Aviso de Ana')]));
      await cargaAnterior;
      expect(c.avisos.single.id, 'cuenta2');
      c.dispose();
    },
  );

  test(
    'Un fallo de red mantiene los avisos reales y permite recuperar',
    () async {
      var fallar = false;
      final c = controlador(
        (_) async => fallar
            ? respuesta({'error': 'Servidor no disponible'}, 503)
            : respuesta([aviso('uno')]),
      );
      await c.cambiarUsuario(1);
      fallar = true;
      await c.actualizar();
      expect(c.error, 'Servidor no disponible');
      expect(c.noLeidas, 1);
      expect(c.cargando, isFalse);
      fallar = false;
      await c.actualizar();
      expect(c.error, isNull);
      c.dispose();
    },
  );

  test(
    'Guardar lectura informa fallos y recupera en el siguiente intento',
    () async {
      final memoria = MemoriaAvisos()..fallar = true;
      final c = controlador((_) async => respuesta([aviso('uno')]), memoria);
      await c.cambiarUsuario(1);
      await c.leerTodas();
      expect(c.errorGuardado, isNotNull);
      memoria.fallar = false;
      await c.leer(c.avisos.single);
      expect(c.errorGuardado, isNull);
      expect(memoria.datos[1], contains('uno'));
      c.dispose();
    },
  );

  test('Las escrituras rápidas no pierden la lectura o el descarte', () async {
    final memoria = MemoriaAvisos();
    final c = controlador(
      (_) async => respuesta([aviso('uno'), aviso('dos')]),
      memoria,
    );
    await c.cambiarUsuario(1);
    await Future.wait([c.leerTodas(), c.vaciar()]);
    final guardado = jsonDecode(memoria.datos[1]!) as Map;
    expect(guardado['leidas'], ['uno', 'dos']);
    expect(guardado['ocultas'], ['uno', 'dos']);
    c.dispose();
  });

  test('Cerrar el controlador mientras carga ignora la respuesta', () async {
    final carga = Completer<http.Response>();
    final inicio = Completer<void>();
    final c = controlador((_) {
      inicio.complete();
      return carga.future;
    });
    final tarea = c.cambiarUsuario(1);
    await inicio.future;
    c.dispose();
    carga.complete(respuesta([aviso('uno')]));
    await tarea;
  });

  Future<void> mostrar(
    WidgetTester tester,
    NotificacionesController c,
    ValueNotifier<AuthUser?> sesion, {
    Size size = const Size(390, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      c.dispose();
      sesion.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [chatRouteObserver],
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          body: Stack(
            children: [
              BotonesFlotantes(onChat: () {}, controlador: c, sesion: sesion),
            ],
          ),
        ),
        routes: {
          '/solicitudes': (ctx) => Scaffold(
            body: Text('Solicitudes ${ModalRoute.of(ctx)!.settings.arguments}'),
          ),
          '/mis-servicios': (_) =>
              const Scaffold(body: Text('Servicios propios')),
          '/servicio': (ctx) => Scaffold(
            body: Text('Servicio ${ModalRoute.of(ctx)!.settings.arguments}'),
          ),
        },
      ),
    );
    await tester.pumpAndSettle();
  }

  ValueNotifier<AuthUser?> cuenta() => ValueNotifier(
    const AuthUser(id: 1, nombre: 'Ana', correo: 'ana@example.test', idRol: 2),
  );

  testWidgets('Campana real: contador, lectura, navegación y descarte', (
    tester,
  ) async {
    final c = controlador(
      (_) async =>
          respuesta([aviso('uno', texto: 'Solicitud aceptada', argumento: 1)]),
    );
    await mostrar(tester, c, cuenta());
    final semantics = tester.ensureSemantics();
    await tester.pump();
    try {
      expect(
        find.bySemanticsLabel(RegExp(r'^Notificaciones, 1 sin leer')),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
    }
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();
    expect(find.text('Solicitud aceptada'), findsOneWidget);
    expect(find.textContaining('Carlos dejó'), findsNothing);
    await tester.tap(find.text('Solicitud aceptada'));
    await tester.pumpAndSettle();
    expect(find.text('Solicitudes 1'), findsOneWidget);
    expect(c.noLeidas, 0);
    final nav = tester.state<NavigatorState>(find.byType(Navigator));
    nav.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Descartar avisos de este dispositivo'));
    await tester.pumpAndSettle();
    expect(find.text('No tienes notificaciones pendientes'), findsOneWidget);
    await c.actualizar();
    await tester.pumpAndSettle();
    expect(find.text('Solicitud aceptada'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Error inicial, reintento y panel en pantalla pequeña', (
    tester,
  ) async {
    var fallar = true;
    final c = controlador(
      (_) async => fallar
          ? respuesta({'error': 'Sin conexión'}, 503)
          : respuesta([aviso('uno')]),
    );
    await mostrar(tester, c, cuenta(), size: const Size(320, 480));
    await tester.tap(find.byIcon(Icons.notifications));
    await tester.pumpAndSettle();
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('No tienes notificaciones pendientes'), findsNothing);
    fallar = false;
    await tester.tap(find.byTooltip('Actualizar notificaciones'));
    await tester.pumpAndSettle();
    expect(find.text('Ana solicitó tu servicio'), findsOneWidget);
    await tester.tap(find.text('Marcar todas leídas'));
    await tester.pumpAndSettle();
    expect(c.noLeidas, 0);
    expect(tester.takeException(), isNull);
  });

  for (final destino in ['mis-servicios', 'servicio']) {
    testWidgets('El aviso abre $destino', (tester) async {
      final c = controlador(
        (_) async => respuesta([aviso('uno', destino: destino, argumento: 69)]),
      );
      await mostrar(tester, c, cuenta());
      await tester.tap(find.byIcon(Icons.notifications));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ana solicitó tu servicio'));
      await tester.pumpAndSettle();
      expect(
        find.text(destino == 'servicio' ? 'Servicio 69' : 'Servicios propios'),
        findsOneWidget,
      );
    });
  }
}
