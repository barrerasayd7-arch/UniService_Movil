import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../core/env.dart';
import 'api_client.dart';
import 'auth_repository.dart';

class Notificacion {
  final String id;
  final String texto;
  final DateTime? fecha;
  final String destino;
  final int argumento;
  const Notificacion({
    required this.id,
    required this.texto,
    required this.destino,
    required this.argumento,
    this.fecha,
  });

  factory Notificacion.fromJson(Map<String, dynamic> j) => Notificacion(
    id: j['id'] as String,
    texto: j['texto'] as String,
    fecha: DateTime.tryParse(j['fecha'] as String? ?? ''),
    destino: j['destino'] as String,
    argumento: (j['argumento'] as num).toInt(),
  );
}

/// Sólo guarda identificadores; no persiste mensajes ni mezcla cuentas o APIs.
class NotificacionesStore {
  final FlutterSecureStorage storage;
  final String namespace;
  NotificacionesStore({FlutterSecureStorage? storage, String? namespace})
    : storage = storage ?? const FlutterSecureStorage(),
      namespace = namespace ?? Env.apiUrl;
  String _clave(int usuario) =>
      'notificaciones_v1_${Uri.encodeComponent(namespace)}_$usuario';
  Future<String?> leer(int usuario) => storage.read(key: _clave(usuario));
  Future<void> guardar(int usuario, String valor) =>
      storage.write(key: _clave(usuario), value: valor);
}

/// Estado de la campana. La API aporta actividad; la lectura es local al dispositivo.
class NotificacionesController extends ChangeNotifier {
  NotificacionesController({ApiClient? api, NotificacionesStore? store})
    : _api = api ?? AuthRepository.instance.api,
      _store = store ?? NotificacionesStore();
  final ApiClient _api;
  final NotificacionesStore _store;
  int? _usuario;
  int _generacion = 0;
  bool _destruido = false;
  bool _restaurando = false;
  int? _consultando;
  bool _repetir = false;
  Future<void> _escritura = Future.value();
  List<Notificacion> _datos = [];
  Set<String> _leidas = {};
  Set<String> _ocultas = {};
  bool cargando = false;
  String? error;
  String? errorGuardado;

  List<Notificacion> get avisos =>
      _datos.where((n) => !_ocultas.contains(n.id)).toList();
  int get noLeidas => avisos.where((n) => !leida(n)).length;
  bool leida(Notificacion n) => _leidas.contains(n.id);
  bool _vigente(int g) => !_destruido && g == _generacion;
  void _avisar() {
    if (!_destruido) notifyListeners();
  }

  Future<void> cambiarUsuario(int? usuario) async {
    if (_usuario == usuario) return;
    _usuario = usuario;
    final g = ++_generacion;
    _datos = [];
    _leidas = {};
    _ocultas = {};
    error = null;
    errorGuardado = null;
    _repetir = false;
    _restaurando = usuario != null;
    cargando = usuario != null;
    _avisar();
    if (usuario == null) return;
    try {
      // Evita leer antes de una escritura pendiente de la misma cuenta.
      await _escritura;
      if (!_vigente(g)) return;
      final valor = await _store.leer(usuario);
      if (!_vigente(g)) return;
      if (valor != null) {
        final j = jsonDecode(valor) as Map;
        _leidas = (j['leidas'] as List).cast<String>().toSet();
        _ocultas = (j['ocultas'] as List).cast<String>().toSet();
      }
    } catch (_) {
      if (_vigente(g)) {
        errorGuardado =
            'No se pudo recuperar la lectura guardada en este dispositivo.';
      }
    }
    if (!_vigente(g)) return;
    _restaurando = false;
    await actualizar();
  }

  Future<void> actualizar() async {
    if (_usuario == null || _destruido || _restaurando) return;
    final g = _generacion;
    if (_consultando == g) {
      _repetir = true;
      return;
    }
    _consultando = g;
    cargando = true;
    _avisar();
    try {
      final data = await _api.get('/api/notificaciones') as List;
      if (!_vigente(g)) return;
      _datos = data
          .map((j) => Notificacion.fromJson(j as Map<String, dynamic>))
          .toList();
      error = null;
    } on ApiException catch (e) {
      if (_vigente(g)) error = e.mensaje;
    } catch (_) {
      if (_vigente(g)) {
        error =
            'No pudimos interpretar las notificaciones. Intenta actualizar.';
      }
    } finally {
      if (_consultando == g) _consultando = null;
      if (_vigente(g)) {
        cargando = false;
        _avisar();
        if (_repetir) {
          _repetir = false;
          actualizar();
        }
      }
    }
  }

  Future<void> leer(Notificacion n) async {
    if (!_datos.any((actual) => actual.id == n.id) || _usuario == null) return;
    _leidas.add(n.id);
    _avisar();
    await _guardar();
  }

  Future<void> leerTodas() async {
    _leidas.addAll(avisos.map((n) => n.id));
    _avisar();
    await _guardar();
  }

  Future<void> vaciar() async {
    _ocultas.addAll(avisos.map((n) => n.id));
    _avisar();
    await _guardar();
  }

  Future<void> _guardar() async {
    final usuario = _usuario;
    if (usuario == null) return;
    final g = _generacion;
    // Límite amplio respecto a los 100 avisos que devuelve la API.
    final valor = jsonEncode({
      'leidas': _leidas.toList().reversed.take(2000).toList().reversed.toList(),
      'ocultas': _ocultas
          .toList()
          .reversed
          .take(2000)
          .toList()
          .reversed
          .toList(),
    });
    _escritura = _escritura.then((_) async {
      try {
        await _store.guardar(usuario, valor);
        if (_vigente(g)) errorGuardado = null;
      } catch (_) {
        if (_vigente(g)) {
          errorGuardado = 'No se pudo guardar la lectura en este dispositivo.';
        }
      }
      if (_vigente(g)) _avisar();
    });
    await _escritura;
  }

  @override
  void dispose() {
    _destruido = true;
    _generacion++;
    super.dispose();
  }
}
