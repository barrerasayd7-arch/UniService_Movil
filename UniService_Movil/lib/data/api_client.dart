import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/env.dart';

/// Error de la API con un mensaje listo para mostrar al usuario.
class ApiException implements Exception {
  final int
  status; // 0 = no hubo respuesta (sin red, servidor apagado, timeout)
  final String mensaje;
  final bool suspendida;

  /// Cuerpo JSON del error (campos extra como intentos_restantes o bloqueado_hasta).
  final Map<String, dynamic>? datos;

  const ApiException(
    this.status,
    this.mensaje, {
    this.suspendida = false,
    this.datos,
  });

  bool get sinConexion => status == 0;

  /// El panel admin pide (otra vez) la contraseña de administrador: la sesión sigue válida.
  bool get requiereElevacion => datos?['requiere_elevacion'] == true;

  @override
  String toString() => 'ApiException($status): $mensaje';
}

/// Archivo para enviar en un formulario multipart.
typedef ArchivoSubida = ({List<int> bytes, String nombre});

/// Cliente HTTP del backend: añade el JWT, decodifica JSON y traduce errores.
class ApiClient {
  ApiClient({http.Client? client, String? baseUrl})
    : _client = client ?? http.Client(),
      _baseUrl = baseUrl ?? Env.apiUrl;

  final http.Client _client;
  final String _baseUrl;
  static const _timeout = Duration(seconds: 15);
  // Varias fotos por datos móviles tardan más que una petición JSON.
  static const _timeoutSubida = Duration(seconds: 90);

  /// JWT de la sesión actual (null = invitado).
  String? token;

  /// Token de la contraseña de administrador; sólo viaja a /api/admin/*.
  String? adminToken;

  /// Se llama cuando el servidor rechaza la sesión (token vencido o cuenta suspendida).
  void Function(ApiException error)? onSesionInvalida;

  Future<dynamic> get(String path) => _send('GET', path);
  Future<dynamic> post(String path, [Object? body]) =>
      _send('POST', path, body);
  Future<dynamic> put(String path, [Object? body]) => _send('PUT', path, body);
  Future<dynamic> patch(String path, [Object? body]) =>
      _send('PATCH', path, body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// POST multipart: cada archivo va en el campo [campo].
  Future<dynamic> subirArchivos(
    String path,
    String campo,
    List<ArchivoSubida> archivos,
  ) {
    final request = http.MultipartRequest('POST', Uri.parse('$_baseUrl$path'))
      ..files.addAll([
        for (final a in archivos)
          http.MultipartFile.fromBytes(campo, a.bytes, filename: a.nombre),
      ]);
    return _enviar(request, _timeoutSubida);
  }

  Future<dynamic> _send(String method, String path, [Object? body]) {
    final request = http.Request(method, Uri.parse('$_baseUrl$path'));
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    return _enviar(request, _timeout);
  }

  Future<dynamic> _enviar(http.BaseRequest request, Duration timeout) async {
    request.headers['Accept'] = 'application/json';
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (adminToken != null && request.url.path.startsWith('/api/admin/')) {
      request.headers['X-Admin-Elevacion'] = adminToken!;
    }

    final http.Response response;
    try {
      response = await http.Response.fromStream(
        await _client.send(request).timeout(timeout),
      ).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(
        0,
        'El servidor tardó demasiado en responder. Inténtalo de nuevo.',
      );
    } catch (_) {
      throw const ApiException(
        0,
        'No hay conexión con el servidor. Revisa tu internet e inténtalo de nuevo.',
      );
    }

    final dynamic data = _decode(response.body);
    if (response.statusCode >= 200 && response.statusCode < 300) return data;

    final error = ApiException(
      response.statusCode,
      _mensajeDeError(response.statusCode, data),
      suspendida: data is Map && data['suspendida'] == true,
      datos: data is Map<String, dynamic> ? data : null,
    );
    final sesionRechazada =
        (response.statusCode == 401 && token != null) || error.suspendida;
    if (sesionRechazada) onSesionInvalida?.call(error);
    throw error;
  }

  static dynamic _decode(String body) {
    if (body.isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      return null;
    }
  }

  static String _mensajeDeError(int status, dynamic data) {
    if (data is Map) {
      // Errores de validación del modelo: { error, detalles: [{ campo, error }] }
      final detalles = data['detalles'];
      if (detalles is List && detalles.isNotEmpty && detalles.first is Map) {
        final primero = (detalles.first as Map)['error'];
        if (primero is String && primero.isNotEmpty) return primero;
      }
      for (final clave in ['error', 'message', 'mensaje']) {
        final valor = data[clave];
        if (valor is String && valor.isNotEmpty) return valor;
      }
    }
    return switch (status) {
      401 => 'Tu sesión terminó. Inicia sesión de nuevo.',
      403 => 'No tienes permiso para hacer esto.',
      404 => 'No encontramos lo que buscabas.',
      413 => 'Las imágenes pesan demasiado. Usa fotos de menos de 5 MB.',
      429 => 'Demasiados intentos. Espera un minuto y vuelve a intentarlo.',
      503 => 'El servicio no está disponible ahora. Inténtalo más tarde.',
      _ => 'Algo falló en el servidor ($status). Inténtalo de nuevo.',
    };
  }
}
