import 'package:flutter/foundation.dart';

import '../models/chat.dart';
import 'api_client.dart';
import 'chat_repository.dart';

/// Estado del historial, independiente de los widgets y del transporte en vivo.
class ConversacionController extends ChangeNotifier {
  ConversacionController(this.repo, this.idChat, this.miId);
  final ChatRepository repo;
  final int idChat;
  final int miId;
  final List<MensajeChat> _mensajes = [];
  List<MensajeChat> get mensajes => List.unmodifiable(_mensajes);
  bool cargando = false;
  bool cargandoAnteriores = false;
  bool enviando = false;
  bool iniciado = false;
  bool hayAnteriores = false;
  String? error;
  bool disponible = true;
  bool visible = true;
  bool _cerrado = false;
  bool _pendiente = false;
  int? _ultimoSincronizado;

  void confirmarLectura() {
    if (_cerrado) return;
    for (var i = 0; i < _mensajes.length; i++) {
      if (_mensajes[i].idRemitente == miId) {
        _mensajes[i] = _mensajes[i].comoLeido();
      }
    }
    _avisar();
  }

  void _avisar() {
    if (!_cerrado) notifyListeners();
  }

  // Conserva el estado leído cuando llega una respuesta anterior a la confirmación.
  void _mezclar(Iterable<MensajeChat> nuevos) {
    final porId = {for (final m in _mensajes) m.id: m};
    for (final m in nuevos) {
      if (m.id <= 0 || m.idChat != idChat) continue;
      porId[m.id] = porId[m.id]?.leido == true ? m.comoLeido() : m;
    }
    // Marcar leído en el servidor abarca todos los mensajes recibidos hasta ese
    // momento; una confirmación reciente también actualiza las páginas antiguas.
    var ultimoPropioLeido = 0;
    for (final m in porId.values) {
      if (m.idRemitente == miId && m.leido && m.id > ultimoPropioLeido) {
        ultimoPropioLeido = m.id;
      }
    }
    for (final m in porId.values.toList()) {
      if (m.idRemitente == miId && m.id <= ultimoPropioLeido) {
        porId[m.id] = m.comoLeido();
      }
    }
    _mensajes
      ..clear()
      ..addAll(porId.values.toList()..sort((a, b) => a.id.compareTo(b.id)));
  }

  Future<void> actualizar() async {
    if (_cerrado || !visible) return;
    if (cargando) {
      _pendiente = true;
      return;
    }
    cargando = true;
    _avisar();
    try {
      final primeraCarga = !iniciado;
      // El cursor sólo avanza con lecturas REST. Un envío confirmado no debe
      // saltarse mensajes ajenos que llegaron mientras estuvimos desconectados.
      final ultimo = _ultimoSincronizado;
      var pagina = await repo.mensajes(idChat);
      final ultimoRecibido = pagina.isEmpty ? 0 : pagina.last.id;
      final nuevos = [...pagina];
      if (!iniciado) {
        hayAnteriores = pagina.length == ChatRepository.tamanoPagina;
      }
      // Recupera también huecos de >50 mensajes recibidos mientras no había red.
      while (!_cerrado &&
          ultimo != null &&
          pagina.length == ChatRepository.tamanoPagina &&
          pagina.first.id > ultimo) {
        final cursor = pagina.first.id;
        pagina = await repo.mensajes(idChat, antes: cursor);
        nuevos.addAll(pagina);
        if (pagina.isNotEmpty && pagina.first.id >= cursor) break;
      }
      if (_cerrado) return;
      _mezclar(nuevos);
      _ultimoSincronizado = ultimoRecibido > (ultimo ?? 0)
          ? ultimoRecibido
          : ultimo ?? 0;
      iniciado = true;
      error = null;
      _avisar();
      // No marcar conversaciones ocultas ni respuestas que terminaron en segundo plano.
      if (visible &&
          (primeraCarga ||
              _mensajes.any((m) => m.idRemitente != miId && !m.leido))) {
        await repo.marcarLeido(idChat);
        if (_cerrado) return;
        for (var i = 0; i < _mensajes.length; i++) {
          if (_mensajes[i].idRemitente != miId) {
            _mensajes[i] = _mensajes[i].comoLeido();
          }
        }
      }
    } on ApiException catch (e) {
      if (!_cerrado) error = e.mensaje;
    } finally {
      cargando = false;
      _avisar();
      if (_pendiente && !_cerrado && visible) {
        _pendiente = false;
        await actualizar();
      }
    }
  }

  Future<void> anteriores() async {
    if (_cerrado || cargandoAnteriores || !hayAnteriores || _mensajes.isEmpty) {
      return;
    }
    cargandoAnteriores = true;
    _avisar();
    try {
      final pagina = await repo.mensajes(idChat, antes: _mensajes.first.id);
      if (_cerrado) return;
      _mezclar(pagina);
      hayAnteriores = pagina.length == ChatRepository.tamanoPagina;
      error = null;
    } on ApiException catch (e) {
      if (!_cerrado) error = e.mensaje;
    } finally {
      cargandoAnteriores = false;
      _avisar();
    }
  }

  /// Sólo limpia el borrador si el servidor confirmó el envío. Nunca reenvía
  /// automáticamente: un timeout podría ocurrir después de guardar en la BD.
  Future<bool> enviar(String texto) async {
    if (_cerrado || enviando || !disponible) return false;
    enviando = true;
    error = null;
    _avisar();
    try {
      final mensaje = await repo.enviar(idChat, texto);
      if (_cerrado) return false;
      _mezclar([mensaje]);
      return true;
    } on ApiException catch (e) {
      if (!_cerrado) {
        if (e.status == 409) disponible = false;
        error = e.sinConexion || e.status >= 500
            ? 'No se pudo confirmar el envío. Actualiza el chat antes de reenviar para evitar duplicados. Tu texto se conservó.'
            : e.mensaje;
      }
      return false;
    } finally {
      enviando = false;
      _avisar();
    }
  }

  @override
  void dispose() {
    _cerrado = true;
    super.dispose();
  }
}
