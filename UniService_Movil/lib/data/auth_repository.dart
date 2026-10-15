import 'package:flutter/foundation.dart';

import '../models/auth_user.dart';
import 'api_client.dart';
import 'session_store.dart';

typedef VerificacionCorreo = ({String token, bool cuentaExistente});

/// Registro, inicio y cierre de sesión contra la API.
///
/// Flujo de registro: [enviarCodigo] → [verificarCodigo] (devuelve un token de 15 min)
/// → [registrar] con ese token.
class AuthRepository {
  AuthRepository._(this.api, this._store) {
    api.onSesionInvalida = _sesionRechazada;
  }

  static final AuthRepository instance = AuthRepository._(
    ApiClient(),
    SessionStore(),
  );

  final ApiClient api;
  final SessionStore _store;

  /// Usuario con sesión iniciada (null = invitado). Las pantallas pueden escucharlo.
  final ValueNotifier<AuthUser?> usuario = ValueNotifier(null);

  /// Lo asigna la app para llevar al login cuando el servidor cierra la sesión.
  void Function(String mensaje)? onSesionCerrada;

  bool get haySesion => usuario.value != null;

  /// Recupera la sesión guardada al abrir la app.
  Future<void> restaurar() async {
    final sesion = await _store.leer();
    if (sesion == null) return;
    api.token = sesion.token;
    usuario.value = sesion.usuario;
  }

  /// Devuelve los segundos que hay que esperar para pedir otro código.
  Future<int> enviarCodigo(String correo) async {
    final data = await api.post('/api/auth/institutional-email/send-code', {
      'correo': correo,
    });
    return (data is Map ? data['resend_after'] as num? : null)?.toInt() ?? 60;
  }

  Future<VerificacionCorreo> verificarCodigo(
    String correo,
    String codigo,
  ) async {
    final data =
        await api.post('/api/auth/institutional-email/verify-code', {
              'correo': correo,
              'codigo': codigo,
            })
            as Map<String, dynamic>;
    return (
      token: data['verificacion_token'] as String,
      cuentaExistente: data['cuenta_existente'] == true,
    );
  }

  Future<AuthUser> registrar({
    required String correo,
    required String password,
    required String nombre,
    required String apellido,
    required String telefono,
    required String verificacionToken,
  }) async {
    final data = await api.post('/api/auth/register', {
      'correo': correo,
      'password': password,
      'nombre': nombre,
      'apellido': apellido,
      'telefono': telefono,
      'verificacion_token': verificacionToken,
    });
    return _abrirSesion(data as Map<String, dynamic>);
  }

  Future<AuthUser> iniciarSesion(String correo, String password) async {
    final data = await api.post('/api/auth/login', {
      'correo': correo,
      'password': password,
    });
    return _abrirSesion(data as Map<String, dynamic>);
  }

  /// Cambia la contraseña con el token de [verificarCodigo] y abre sesión con la nueva.
  Future<AuthUser> restablecerPassword({
    required String correo,
    required String verificacionToken,
    required String nuevaPassword,
  }) async {
    await api.post('/api/auth/reset-password-verificado', {
      'correo': correo,
      'verificacion_token': verificacionToken,
      'nueva_password': nuevaPassword,
    });
    return iniciarSesion(correo, nuevaPassword);
  }

  /// Cambia la contraseña con la sesión abierta. El servidor cierra todas las sesiones
  /// (también las de otros dispositivos) y devuelve un token nuevo para éste.
  Future<void> cambiarPassword(String actual, String nueva) async {
    final data =
        await api.post('/api/auth/change-password', {
              'ContrasenaActual': actual,
              'ContrasenaNueva': nueva,
            })
            as Map<String, dynamic>;
    final token = data['token'] as String;
    final user = usuario.value!;
    await _store.guardar(token, user);
    api.token = token;
  }

  Future<void> cerrarSesion() async {
    if (usuario.value != null) {
      // El servidor invalida el token (y los de otros dispositivos); si falla, se sale igual.
      try {
        await api.post('/api/auth/logout');
      } on ApiException {
        // Sin red: no impide salir.
      }
    }
    await _limpiar();
  }

  Future<AuthUser> _abrirSesion(Map<String, dynamic> data) async {
    final token = data['token'] as String;
    final user = AuthUser.fromJson(data['user'] as Map<String, dynamic>);
    await _store.guardar(token, user);
    api.token = token;
    usuario.value = user;
    return user;
  }

  Future<void> _limpiar() async {
    api.token = null;
    api.adminToken = null;
    usuario.value = null;
    await _store.borrar();
  }

  void _sesionRechazada(ApiException error) {
    if (!haySesion) return;
    _limpiar();
    onSesionCerrada?.call(
      error.suspendida
          ? 'Tu cuenta fue suspendida. Si crees que es un error, contacta al administrador.'
          : 'Tu sesión terminó. Inicia sesión de nuevo.',
    );
  }
}
