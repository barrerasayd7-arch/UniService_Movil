import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:app_uniservice/data/chat_realtime.dart';
import 'package:app_uniservice/data/solicitudes_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fakes/chat_api_falsa.dart';

/// Servidor SignalR mínimo en loopback: negociación, handshake y eventos reales
/// WebSocket. No utiliza credenciales, procesos .NET ni datos de Supabase.
void main() {
  test(
    'SignalR autentica, entrega mensajes/lecturas y se desconecta al salir',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final sockets = <WebSocket>[];
      final autenticaciones = <String?>[];
      final listo = Completer<WebSocket>();
      server.listen((request) async {
        if (request.uri.path.endsWith('/negotiate')) {
          autenticaciones.add(
            request.headers.value(HttpHeaders.authorizationHeader),
          );
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'negotiateVersion': 1,
              'connectionId': 'prueba',
              'connectionToken': 'prueba',
              'availableTransports': [
                {
                  'transport': 'WebSockets',
                  'transferFormats': ['Text'],
                },
              ],
            }),
          );
          await request.response.close();
        } else if (WebSocketTransformer.isUpgradeRequest(request)) {
          final socket = await WebSocketTransformer.upgrade(request);
          sockets.add(socket);
          socket.listen((data) {
            if (data.toString().contains('"protocol"')) {
              socket.add('{}\u001e');
              if (!listo.isCompleted) listo.complete(socket);
            }
          });
        } else {
          request.response.statusCode = 404;
          await request.response.close();
        }
      });
      final api = ChatApiFalsa();
      final solicitudes = SolicitudesRepository();
      int? usuario = 1;
      final vivo = ChatRealtime(
        repositorio: api.repo,
        solicitudes: solicitudes,
        baseUrl: 'http://127.0.0.1:${server.port}',
        usuarioActual: () => usuario,
        tokenActual: () => usuario == null ? null : 'jwt-prueba',
      );
      addTearDown(() async {
        await vivo.desconectar();
        for (final socket in sockets) {
          await socket.close();
        }
        await server.close(force: true);
        vivo.conectado.dispose();
        solicitudes.cambios.dispose();
      });
      await vivo.conectar().timeout(const Duration(seconds: 10));
      final socket = await listo.future.timeout(const Duration(seconds: 5));
      expect(autenticaciones, ['Bearer jwt-prueba']);
      expect(vivo.conectado.value, isTrue);

      final cambio = api.repo.cambios.firstWhere((id) => id == 7);
      socket.add(
        '${jsonEncode({
          'type': 1,
          'target': 'RecibirMensaje',
          'arguments': [
            {'id_chat': 7},
          ],
        })}\u001e',
      );
      expect(await cambio.timeout(const Duration(seconds: 5)), 7);

      final lectura = api.repo.lecturas.first;
      socket.add(
        '${jsonEncode({
          'type': 1,
          'target': 'MensajesLeidos',
          'arguments': [
            {'id_chat': 7},
          ],
        })}\u001e',
      );
      expect(await lectura.timeout(const Duration(seconds: 5)), 7);

      final aviso = Completer<void>();
      void cambioSolicitud() {
        if (!aviso.isCompleted) aviso.complete();
      }

      solicitudes.cambios.addListener(cambioSolicitud);
      socket.add(
        '${jsonEncode({
          'type': 1,
          'target': 'SolicitudActualizada',
          'arguments': [
            {'id_solicitud': 40},
          ],
        })}\u001e',
      );
      await aviso.future.timeout(const Duration(seconds: 5));
      solicitudes.cambios.removeListener(cambioSolicitud);

      usuario = null;
      await vivo.desconectar();
      expect(vivo.conectado.value, isFalse);
      await vivo.conectar();
      expect(autenticaciones.length, 1);
    },
  );
}
