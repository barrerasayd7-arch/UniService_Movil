import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:signalr_netcore/hub_connection.dart';
import 'package:signalr_netcore/hub_connection_builder.dart';
import 'package:signalr_netcore/http_connection_options.dart';

import '../core/env.dart';
import 'auth_repository.dart';
import 'chat_repository.dart';

/// Una conexión por sesión. Los eventos invalidan REST, que también recupera
/// los mensajes perdidos durante una desconexión. No se registran tokens en logs.
class ChatRealtime {
  ChatRealtime({
    ChatRepository? repositorio,
    String? baseUrl,
    int? Function()? usuarioActual,
    String? Function()? tokenActual,
  }) : _repo = repositorio ?? ChatRepository.instance,
       _baseUrl = baseUrl ?? Env.apiUrl,
       _usuarioActual =
           usuarioActual ?? (() => AuthRepository.instance.usuario.value?.id),
       _tokenActual = tokenActual ?? (() => AuthRepository.instance.api.token);
  static final instance = ChatRealtime();
  final ChatRepository _repo;
  final String _baseUrl;
  final int? Function() _usuarioActual;
  final String? Function() _tokenActual;
  final conectado = ValueNotifier(false);
  HubConnection? _hub;
  StreamSubscription<HubConnectionState>? _estado;

  Future<void> conectar() async {
    final id = _usuarioActual();
    if (id == null || _tokenActual() == null) return;
    var hub = _hub;
    if (hub != null && hub.state != HubConnectionState.Disconnected) return;
    if (hub == null) {
      hub = HubConnectionBuilder()
          .withUrl(
            '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/chathub',
            options: HttpConnectionOptions(
              accessTokenFactory: () async =>
                  _usuarioActual() == id ? _tokenActual() ?? '' : '',
            ),
          )
          .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000])
          .build();
      _hub = hub;
      final actual = hub;
      _estado = hub.stateStream.listen((estado) {
        if (_hub != actual) return;
        conectado.value = estado == HubConnectionState.Connected;
        if (conectado.value) _repo.avisarCambio();
      });
      void cambio(List<Object?>? argumentos) {
        if (_hub != actual || _usuarioActual() != id) return;
        final data = argumentos?.isNotEmpty == true ? argumentos!.first : null;
        final chat = data is Map ? (data['id_chat'] as num?)?.toInt() : null;
        _repo.avisarCambio(chat);
      }

      hub.on('RecibirMensaje', cambio);
      hub.on('MensajesLeidos', (argumentos) {
        if (_hub != actual || _usuarioActual() != id) return;
        final data = argumentos?.isNotEmpty == true ? argumentos!.first : null;
        final chat = data is Map ? (data['id_chat'] as num?)?.toInt() : null;
        if (chat != null) _repo.confirmarLectura(chat);
      });
    }
    try {
      await hub.start();
    } catch (_) {
      // La sesión reintenta; la bandeja y el historial siguen funcionando por REST.
      if (_hub == hub) conectado.value = false;
    }
  }

  Future<void> desconectar() async {
    final anterior = _hub;
    _hub = null; // Ignora inmediatamente callbacks de la sesión anterior.
    final estado = _estado;
    _estado = null;
    conectado.value = false;
    await estado?.cancel();
    if (anterior != null) {
      try {
        await anterior.stop();
      } catch (_) {
        /* Ya se perdió el transporte. */
      }
    }
  }
}
