// Archivo: session_store.dart
// Responsabilidad: persistir y recuperar JWT + AuthUser en el almacenamiento cifrado,
//   descartando sesiones vencidas o corruptas.
// Se usa desde: AuthRepository (restaurar, guardar tras login y borrar al salir).
import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/auth_user.dart';

typedef SesionGuardada = ({String token, AuthUser usuario});

/// Guarda el JWT y el usuario en el almacenamiento cifrado del dispositivo
/// (Keystore en Android, Keychain en iOS).
class SessionStore {
  SessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static const _kToken = 'sesion_token';
  static const _kUsuario = 'sesion_usuario';

  /// Sobrescribe la sesión guardada (token + usuario serializado).
  Future<void> guardar(String token, AuthUser usuario) async {
    await _storage.write(key: _kToken, value: token);
    await _storage.write(key: _kUsuario, value: jsonEncode(usuario.toJson()));
  }

  /// Devuelve la sesión si existe y su token no ha vencido.
  Future<SesionGuardada?> leer() async {
    try {
      final token = await _storage.read(key: _kToken);
      final usuario = await _storage.read(key: _kUsuario);
      if (token == null || usuario == null || _vencido(token)) return null;
      return (
        token: token,
        usuario: AuthUser.fromJson(jsonDecode(usuario) as Map<String, dynamic>),
      );
    } catch (_) {
      // Datos corruptos o almacenamiento no disponible: se empieza sin sesión.
      return null;
    }
  }

  /// Elimina ambos registros; se llama al cerrar sesión o si el servidor la rechaza.
  Future<void> borrar() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kUsuario);
  }

  /// Lee el campo `exp` del JWT (sin verificar la firma: eso lo hace el servidor).
  static bool _vencido(String token) {
    final partes = token.split('.');
    if (partes.length != 3) return true;
    final payload = jsonDecode(
      utf8.decode(base64Url.decode(base64Url.normalize(partes[1]))),
    );
    final exp = payload is Map ? payload['exp'] : null;
    if (exp is! num) return true;
    final vence = DateTime.fromMillisecondsSinceEpoch(
      exp.toInt() * 1000,
      isUtc: true,
    );
    // Margen de un minuto para no arrancar con un token a punto de expirar.
    return DateTime.now().toUtc().isAfter(
      vence.subtract(const Duration(minutes: 1)),
    );
  }
}
