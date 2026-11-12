import 'dart:async';
import 'dart:convert';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/chat_repository.dart';
import 'package:app_uniservice/data/conversacion_controller.dart';
import 'package:app_uniservice/models/chat.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'fakes/chat_api_falsa.dart';

void main() {
  test('Una respuesta tardía de otra sesión no expulsa a la cuenta nueva', () async {
    final respuesta = Completer<http.Response>();
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((_) => respuesta.future))..token = 'sesion-anterior';
    var cierres = 0;
    api.onSesionInvalida = (_) => cierres++;
    final consulta = api.get('/api/chat/no-leidos');
    final rechazo = expectLater(consulta, throwsA(isA<ApiException>()));
    api.token = 'sesion-nueva';
    respuesta.complete(http.Response('{"suspendida":true}', 403));
    await rechazo;
    expect(cierres, 0);
  });

  test('Un 401 de la sesión actual conserva el cierre de sesión global', () async {
    final api = ApiClient(baseUrl: 'http://api.test', client: MockClient((_) async => http.Response('{}', 401)))..token = 'actual';
    var cierres = 0;
    api.onSesionInvalida = (_) => cierres++;
    await expectLater(api.get('/api/chat/no-leidos'), throwsA(isA<ApiException>()));
    expect(cierres, 1);
  });

  test('REST usa JWT, el participante y el contrato real de envío', () async {
    final api = ChatApiFalsa();
    final chats = await api.repo.listar();
    expect(chats.first.otro.nombre, 'Laura Pérez');
    expect(chats.first.otro.enLinea, isTrue);
    expect(await api.repo.iniciar(2), 7);
    final mensaje = await api.repo.enviar(7, '  Hola Laura  ');
    expect(mensaje.texto, 'Hola Laura');
    expect(mensaje.idRemitente, 1);
    expect(
      api.peticiones.every(
        (r) => r.headers['Authorization'] == 'Bearer jwt-de-prueba',
      ),
      isTrue,
    );
    expect(jsonDecode(api.peticiones.last.body), {'mensaje': 'Hola Laura'});
    expect(jsonDecode(api.peticiones[1].body), {'id_usuario': 2});
    expect(await api.repo.noLeidos(), 3);
  });

  test('No envía textos vacíos ni mayores a 2000 caracteres', () async {
    final api = ChatApiFalsa();
    await expectLater(api.repo.enviar(7, ' \n '), throwsA(isA<ApiException>()));
    await expectLater(
      api.repo.enviar(7, 'a' * 2001),
      throwsA(isA<ApiException>()),
    );
    expect(api.peticiones, isEmpty);
  });

  test('Historial paginado, sin duplicados y con lectura confirmada', () async {
    final api = ChatApiFalsa()
      ..datos.addAll([for (var i = 1; i <= 65; i++) mensajeFalso(i)]);
    final c = ConversacionController(api.repo, 7, 1);
    addTearDown(c.dispose);
    await c.actualizar();
    expect(c.mensajes.length, 50);
    expect(c.mensajes.first.id, 16);
    expect(c.hayAnteriores, isTrue);
    expect(api.lecturas, 1);
    await c.anteriores();
    expect(
      c.mensajes.map((m) => m.id),
      orderedEquals([for (var i = 1; i <= 65; i++) i]),
    );
    expect(c.hayAnteriores, isFalse);
    await c.actualizar();
    expect(c.mensajes.length, 65);
    expect(api.lecturas, 1);
  });

  test(
    'Tras una desconexión recupera más de una página nueva sin huecos',
    () async {
      final api = ChatApiFalsa()..datos.add(mensajeFalso(1));
      final c = ConversacionController(api.repo, 7, 1);
      addTearDown(c.dispose);
      await c.actualizar();
      api.datos.addAll([for (var i = 2; i <= 132; i++) mensajeFalso(i)]);
      await c.actualizar();
      expect(
        c.mensajes.map((m) => m.id),
        orderedEquals([for (var i = 1; i <= 132; i++) i]),
      );
    },
  );

  test(
    'Enviar y recibir la misma actualización sólo muestra un mensaje',
    () async {
      final api = ChatApiFalsa();
      final c = ConversacionController(api.repo, 7, 1);
      addTearDown(c.dispose);
      await c.actualizar();
      expect(await c.enviar('Hola'), isTrue);
      await c.actualizar();
      expect(c.mensajes.length, 1);
      expect(c.mensajes.single.texto, 'Hola');
      c.confirmarLectura();
      // Una respuesta antigua con leido=false no revierte una confirmación de SignalR.
      await c.actualizar();
      expect(c.mensajes.single.leido, isTrue);
    },
  );

  test(
    'Enviar tras estar desconectado no salta mensajes ajenos aún no sincronizados',
    () async {
      final api = ChatApiFalsa()..datos.add(mensajeFalso(1));
      final c = ConversacionController(api.repo, 7, 1);
      addTearDown(c.dispose);
      await c.actualizar();
      api.datos.addAll([for (var i = 2; i <= 120; i++) mensajeFalso(i)]);
      await c.enviar('Ya volví');
      await c.actualizar();
      expect(
        c.mensajes.map((m) => m.id),
        orderedEquals([for (var i = 1; i <= 121; i++) i]),
      );
    },
  );

  test(
    'Abrir el chat marca también no leídos anteriores a la primera página',
    () async {
      final api = ChatApiFalsa()
        ..datos.addAll([
          mensajeFalso(1),
          for (var i = 2; i <= 60; i++) mensajeFalso(i, remitente: 1),
        ]);
      final c = ConversacionController(api.repo, 7, 1);
      addTearDown(c.dispose);
      await c.actualizar();
      expect(api.datos.first['leido'], isTrue);
    },
  );

  test(
    'Un fallo conserva el historial y permite volver a sincronizar',
    () async {
      final api = ChatApiFalsa()..datos.add(mensajeFalso(1));
      final c = ConversacionController(api.repo, 7, 1);
      addTearDown(c.dispose);
      await c.actualizar();
      api.errorMensajes = 503;
      await c.actualizar();
      expect(c.mensajes.length, 1);
      expect(c.error, isNotNull);
      api.errorMensajes = null;
      await c.actualizar();
      expect(c.error, isNull);
      api.errorEnvio = 503;
      expect(await c.enviar('¿Sigues disponible?'), isFalse);
      expect(c.error, contains('Tu texto se conservó'));
      expect(c.mensajes.length, 1);
      expect(api.peticiones.where((r) => r.method == 'POST').length, 1);
    },
  );

  test('Una cuenta no disponible deja el chat de solo lectura', () async {
    final api = ChatApiFalsa()..errorEnvio = 409;
    final c = ConversacionController(api.repo, 7, 1);
    addTearDown(c.dispose);
    expect(await c.enviar('Hola'), isFalse);
    expect(c.disponible, isFalse);
    expect(await c.enviar('Segundo intento'), isFalse);
    expect(api.peticiones.length, 1);
  });

  test(
    'No marca como leído si se oculta mientras espera la respuesta',
    () async {
      final respuesta = Completer<http.Response>();
      var lecturas = 0;
      final repo = ChatRepository(
        ApiClient(
          baseUrl: 'http://api.test',
          client: MockClient((r) {
            if (r.method == 'PUT') lecturas++;
            return respuesta.future;
          }),
        ),
      );
      final c = ConversacionController(repo, 7, 1);
      addTearDown(c.dispose);
      final carga = c.actualizar();
      c.visible = false;
      respuesta.complete(http.Response(jsonEncode([mensajeFalso(1)]), 200));
      await carga;
      expect(lecturas, 0);
      expect(c.mensajes.length, 1);
    },
  );

  test(
    'Salir durante una petición no notifica un controlador destruido',
    () async {
      final respuesta = Completer<http.Response>();
      final repo = ChatRepository(
        ApiClient(
          baseUrl: 'http://api.test',
          client: MockClient((_) => respuesta.future),
        ),
      );
      final c = ConversacionController(repo, 7, 1);
      final carga = c.actualizar();
      c.dispose();
      respuesta.complete(http.Response('[]', 200));
      await carga;
      expect(c.mensajes, isEmpty);
    },
  );

  test('Los mensajes de solicitud se reconocen como sistema', () {
    final m = MensajeChat.fromJson(mensajeFalso(3, tipo: 'sistema'));
    expect(m.esSistema, isTrue);
    final chat = Conversacion.fromJson({
      'id_chat': 9,
      'otro': {'id': 4, 'nombre': 'Usuario no disponible', 'disponible': false},
      'no_leidos': 2,
    });
    expect(chat.otro.disponible, isFalse);
    expect(chat.otro.avatar, isNull);
    expect(chat.noLeidos, 2);
  });
}
