import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Preferencia del dispositivo, independiente del inicio y cierre de sesión.
class TemaController extends ChangeNotifier {
  TemaController({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();
  static final instance = TemaController();
  static const clave = 'uniservice_tema';
  final FlutterSecureStorage _storage;
  ThemeMode _modo = ThemeMode.dark;
  ThemeMode get modo => _modo;
  bool get oscuro => _modo == ThemeMode.dark;
  int _revision = 0;
  Future<void>? _escritura;

  Future<void> restaurar() async {
    final revision = _revision;
    try {
      final guardado = await _storage.read(key: clave);
      if (revision != _revision) return;
      _modo = guardado == 'claro' ? ThemeMode.light : ThemeMode.dark;
      notifyListeners();
    } catch (_) {
      // Sin acceso al almacenamiento, la app conserva el tema predeterminado.
    }
  }

  Future<bool> alternar() async {
    _revision++;
    _modo = oscuro ? ThemeMode.light : ThemeMode.dark;
    final valor = oscuro ? 'oscuro' : 'claro';
    notifyListeners();
    var guardado = true;
    final pendiente = _escritura;
    Future<void> guardar() async {
      if (pendiente != null) await pendiente;
      try {
        await _storage.write(key: clave, value: valor);
      } catch (_) {
        guardado = false;
      }
    }

    final escritura = guardar();
    _escritura = escritura;
    await escritura;
    if (identical(_escritura, escritura)) _escritura = null;
    return guardado;
  }
}
