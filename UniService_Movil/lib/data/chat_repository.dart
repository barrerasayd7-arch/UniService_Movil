import 'dart:async';

import '../models/chat.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// REST es la fuente de verdad. SignalR avisa de cambios y las pantallas
/// reconcilian por id: una reconexión o la respuesta al enviar no duplica mensajes.
class ChatRepository {
  ChatRepository([ApiClient? api]) : _api = api ?? AuthRepository.instance.api;
  static final instance = ChatRepository();
  final ApiClient _api;
  final _cambios = StreamController<int?>.broadcast();
  final _lecturas = StreamController<int>.broadcast();
  Stream<int?> get cambios => _cambios.stream;
  Stream<int> get lecturas => _lecturas.stream;
  void avisarCambio([int? idChat]) => _cambios.add(idChat);
  void confirmarLectura(int idChat) {
    _lecturas.add(idChat);
    avisarCambio(idChat);
  }

  Future<List<Conversacion>> listar() async {
    final data = await _api.get('/api/chat/mis-chats') as List;
    return [
      for (final j in data) Conversacion.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<int> iniciar(int idUsuario) async {
    final data =
        await _api.post('/api/chat/iniciar', {'id_usuario': idUsuario}) as Map;
    final id = (data['id_chat'] as num).toInt();
    avisarCambio(id);
    return id;
  }

  static const tamanoPagina = 50;
  Future<List<MensajeChat>> mensajes(int idChat, {int? antes}) async {
    final query = Uri(
      queryParameters: {
        'limite': '$tamanoPagina',
        if (antes != null) 'antes': '$antes',
      },
    ).query;
    final data = await _api.get('/api/chat/$idChat/mensajes?$query') as List;
    return [
      for (final j in data) MensajeChat.fromJson(j as Map<String, dynamic>),
    ];
  }

  Future<MensajeChat> enviar(int idChat, String texto) async {
    final limpio = texto.trim();
    if (limpio.isEmpty || limpio.length > 2000) {
      throw const ApiException(
        400,
        'Escribe un mensaje de entre 1 y 2000 caracteres.',
      );
    }
    final data = await _api.post('/api/chat/$idChat/mensajes', {
      'mensaje': limpio,
    });
    final mensaje = MensajeChat.fromJson(data as Map<String, dynamic>);
    avisarCambio(idChat);
    return mensaje;
  }

  Future<void> marcarLeido(int idChat) async {
    final data = await _api.put('/api/chat/$idChat/leido') as Map;
    if ((data['marcados'] as num? ?? 0) > 0) avisarCambio(idChat);
  }

  Future<int> noLeidos() async =>
      ((await _api.get('/api/chat/no-leidos') as Map)['no_leidos'] as num)
          .toInt();

  Future<void> actividad() => _api.put('/api/chat/actividad');
}
