import 'dart:convert';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/chat_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

Map<String, dynamic> mensajeFalso(
  int id, {
  int remitente = 2,
  bool leido = false,
  String? texto,
  String tipo = 'texto',
}) => {
  'id_mensaje': id,
  'id_chat': 7,
  'id_remitente': remitente,
  'mensaje': texto ?? 'Mensaje $id',
  'tipo': tipo,
  'leido': leido,
  'fecha_envio': '2026-11-12T15:30:00Z',
};

class ChatApiFalsa {
  final peticiones = <http.Request>[];
  final datos = <Map<String, dynamic>>[];
  int? errorListado;
  int? errorEnvio;
  int? errorMensajes;
  int lecturas = 0;
  late final api = ApiClient(
    client: MockClient(_responder),
    baseUrl: 'http://api.test',
  )..token = 'jwt-de-prueba';
  late final repo = ChatRepository(api);

  http.Response _json(Object data, [int status = 200]) => http.Response(
    jsonEncode(data),
    status,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  Future<http.Response> _responder(http.Request request) async {
    peticiones.add(request);
    final path = request.url.path;
    if (path == '/api/chat/mis-chats') {
      if (errorListado != null)
        return _json({
          'error': 'No hay conexión con el servidor',
        }, errorListado!);
      return _json([
        {
          'id_chat': 7,
          'otro': {
            'id': 2,
            'nombre': 'Laura Pérez',
            'disponible': true,
            'en_linea': true,
          },
          'ultimo_mensaje': datos.isEmpty ? null : datos.last['mensaje'],
          'ultimo_tipo': 'texto',
          'no_leidos': datos
              .where((m) => m['id_remitente'] != 1 && m['leido'] == false)
              .length,
          'ultimo_fecha': '2026-11-12T15:30:00Z',
        },
        {
          'id_chat': 8,
          'otro': {'id': 3, 'nombre': 'Carlos Gómez', 'disponible': true},
          'ultimo_mensaje': null,
          'no_leidos': 0,
        },
      ]);
    }
    if (path == '/api/chat/iniciar') return _json({'id_chat': 7});
    if (path == '/api/chat/no-leidos') return _json({'no_leidos': 3});
    if (path == '/api/chat/actividad') return _json({'ok': true});
    if (path == '/api/chat/7/leido') {
      lecturas++;
      var marcados = 0;
      for (final m in datos) {
        if (m['id_remitente'] != 1 && m['leido'] == false) {
          m['leido'] = true;
          marcados++;
        }
      }
      return _json({'marcados': marcados});
    }
    if (path == '/api/chat/7/mensajes') {
      if (request.method == 'POST') {
        if (errorEnvio != null)
          return _json({
            'error': 'No puedes enviar mensajes ahora',
          }, errorEnvio!);
        final body = jsonDecode(request.body) as Map;
        final id = datos.isEmpty ? 1 : (datos.last['id_mensaje'] as int) + 1;
        final mensaje = mensajeFalso(
          id,
          remitente: 1,
          texto: body['mensaje'] as String,
        );
        datos.add(mensaje);
        return _json(mensaje);
      }
      if (errorMensajes != null)
        return _json({
          'error': 'El historial no está disponible',
        }, errorMensajes!);
      final antes = int.tryParse(request.url.queryParameters['antes'] ?? '');
      final limite = int.parse(request.url.queryParameters['limite'] ?? '50');
      var pagina = datos
          .where((m) => antes == null || (m['id_mensaje'] as int) < antes)
          .toList();
      pagina = pagina.reversed.take(limite).toList().reversed.toList();
      return _json(pagina);
    }
    return _json({'error': 'Ruta inesperada: $path'}, 404);
  }
}
