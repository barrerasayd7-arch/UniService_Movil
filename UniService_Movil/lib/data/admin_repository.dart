import 'api_client.dart';
import 'auth_repository.dart';

typedef EstadoAccesoAdmin = ({
  String correo,
  bool configurada,
  DateTime? bloqueadoHasta,
});

/// Acceso al panel de administración con la contraseña de administrador
/// (distinta a la de la cuenta). El token que devuelve la API vive sólo en memoria:
/// al cerrar la app o pasar una hora, se vuelve a pedir.
class AdminRepository {
  AdminRepository._(this._auth);

  static final AdminRepository instance = AdminRepository._(
    AuthRepository.instance,
  );

  final AuthRepository _auth;
  DateTime? _vence;

  ApiClient get _api => _auth.api;

  bool get dentroDelPanel =>
      _api.adminToken != null &&
      _vence != null &&
      DateTime.now().toUtc().isBefore(_vence!);

  /// Hasta cuándo dura el acceso actual (null = fuera del panel).
  DateTime? get vence => dentroDelPanel ? _vence : null;

  Future<EstadoAccesoAdmin> estado() async {
    final data = await _api.get('/api/admin/acceso/estado') as Map;
    return (
      correo: (data['correo'] as String?) ?? _auth.usuario.value?.correo ?? '',
      configurada: data['configurada'] == true,
      bloqueadoHasta: fechaApi(data['bloqueado_hasta']),
    );
  }

  /// Valida la contraseña de administrador y abre el panel.
  Future<void> entrar(String clave) async {
    _abrir(await _api.post('/api/admin/acceso/verificar', {'clave': clave}));
  }

  /// Crea o restablece la contraseña con el token del código enviado al correo, y abre el panel.
  Future<void> crearClave({
    required String verificacionToken,
    required String clave,
  }) async {
    _abrir(
      await _api.post('/api/admin/acceso/clave', {
        'verificacion_token': verificacionToken,
        'clave': clave,
      }),
    );
  }

  Future<Map<String, dynamic>> dashboard() async =>
      await _api.get('/api/admin/dashboard') as Map<String, dynamic>;

  void salir() {
    _api.adminToken = null;
    _vence = null;
  }

  void _abrir(dynamic data) {
    final map = data as Map;
    _api.adminToken = map['token'] as String;
    _vence = fechaApi(map['expires_at']);
  }

  /// La API devuelve fechas UTC sin zona ("2026-10-14T18:00:00Z" o sin la Z).
  static DateTime? fechaApi(Object? v) {
    if (v is! String) return null;
    final t = DateTime.tryParse(
      v.endsWith('Z') || v.contains('+') ? v : '${v}Z',
    );
    return t?.toUtc();
  }
}
