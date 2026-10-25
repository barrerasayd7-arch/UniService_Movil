// Archivo: env.dart
// Responsabilidad: resolver la URL base de la API según `--dart-define` y la plataforma.
// Se usa desde: ApiClient y los repositorios, que nunca deben hardcodear el host.

import 'package:flutter/foundation.dart';

/// URL del backend.
///
/// Por defecto apunta a la API local (`dotnet run`, puerto 5165). Para otro
/// destino se pasa al compilar, sin tocar código:
///
///   flutter run --dart-define=API_URL=http://192.168.1.50:5165   (celular físico)
///   flutter build apk --dart-define=API_URL=https://api.serviown.com  (producción)
class Env {
  Env._();

  static const _apiUrl = String.fromEnvironment('API_URL');

  /// URL base de la API; prioriza `--dart-define` y si no, resuelve según la plataforma.
  static String get apiUrl {
    if (_apiUrl.isNotEmpty) return _apiUrl;
    // El emulador de Android ve el PC anfitrión como 10.0.2.2, no como localhost.
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:5165';
    }
    return 'http://localhost:5165';
  }
}
