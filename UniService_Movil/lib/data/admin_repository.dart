// Archivo: admin_repository.dart
// Responsabilidad: hablar con /api/admin/* (acceso, dashboard, usuarios, servicios,
//   reportes y bitácora) y custodiar en memoria el token de elevación del administrador.
// Se usa desde: pantallas de administración vía AdminRepository.instance.
import 'api_client.dart';
import 'auth_repository.dart';
import '../models/admin_models.dart';

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

  /// Hay token de administrador y aún no vence (se comprueba en cada llamada).
  bool get dentroDelPanel =>
      _api.adminToken != null &&
      _vence != null &&
      DateTime.now().toUtc().isBefore(_vence!);

  /// Hasta cuándo dura el acceso actual (null = fuera del panel).
  DateTime? get vence => dentroDelPanel ? _vence : null;

  /// Estado de la contraseña de administrador: si ya está configurada y hasta
  /// cuándo sigue bloqueada por intentos fallidos. No requiere elevación.
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

  /// Totales y métricas de la portada del panel.
  Future<Map<String, dynamic>> dashboard() async =>
      await _api.get('/api/admin/dashboard') as Map<String, dynamic>;

  // Descarta parámetros nulos o vacíos y codifica la query string.
  static String _query(Map<String, String?> p) => Uri(
    queryParameters: {
      for (final e in p.entries)
        if (e.value != null && e.value!.isNotEmpty) e.key: e.value!,
    },
  ).query;

  // ── Usuarios ──
  /// Página de usuarios, filtrable por texto y estado.
  /// [estado]: 'activos' | 'suspendidos' | null (todos).
  Future<PaginaAdmin<AdminUsuario>> usuarios({
    String? busqueda,
    String? estado,
    int page = 1,
  }) async {
    final q = _query({
      'busqueda': busqueda?.trim(),
      'estado': estado,
      'page': '$page',
      'pageSize': '20',
    });
    final data =
        await _api.get('/api/admin/usuarios?$q') as Map<String, dynamic>;
    return PaginaAdmin.fromJson(data, AdminUsuario.fromJson);
  }

  /// Suspende la cuenta; el motivo queda en la bitácora y se le muestra al usuario.
  Future<void> suspenderUsuario(int id, String motivo) =>
      _api.patch('/api/admin/usuarios/$id/suspender', {'motivo': motivo});

  Future<void> reactivarUsuario(int id) =>
      _api.patch('/api/admin/usuarios/$id/reactivar');

  // ── Servicios ──
  /// [estado]: pendiente | aprobado | pausado | rechazado | null (todos).
  Future<PaginaAdmin<AdminServicio>> servicios({
    String? estado,
    String? busqueda,
    int page = 1,
  }) async {
    final q = _query({
      'estado': estado,
      'busqueda': busqueda?.trim(),
      'page': '$page',
      'pageSize': '20',
    });
    final data =
        await _api.get('/api/admin/servicios?$q') as Map<String, dynamic>;
    return PaginaAdmin.fromJson(data, AdminServicio.fromJson);
  }

  Future<void> aprobarServicio(int id) =>
      _api.patch('/api/admin/servicios/$id/aprobar');

  /// Retira un servicio ya publicado o pausado (motivo obligatorio).
  Future<void> ocultarServicio(int id, String motivo) =>
      _api.patch('/api/admin/servicios/$id/ocultar', {'motivo': motivo});

  /// Rechaza un servicio pendiente (el motivo es opcional).
  Future<void> rechazarServicio(int id, String? razon) =>
      _api.post('/api/admin/servicios/$id/rechazar', {'razon': razon});

  // ── Reportes ──
  /// Bandeja de reportes enviados por los usuarios, filtrable por estado.
  Future<PaginaAdmin<AdminReporte>> reportes({
    String? estado,
    int page = 1,
  }) async {
    final q = _query({'estado': estado, 'page': '$page', 'pageSize': '20'});
    final data =
        await _api.get('/api/admin/reportes?$q') as Map<String, dynamic>;
    return PaginaAdmin.fromJson(data, AdminReporte.fromJson);
  }

  /// Cambia el estado del reporte; una nota vacía se envía como null.
  Future<void> actualizarReporte(int id, String estado, String? notas) =>
      _api.patch('/api/admin/reportes/$id', {
        'estado': estado,
        'resolucion_notas': (notas == null || notas.isEmpty) ? null : notas,
      });

  // ── Bitácora ──
  /// Registro de acciones administrativas, filtrable por entidad afectada.
  Future<PaginaAdmin<AdminAuditoria>> auditoria({
    String? entidad,
    int page = 1,
  }) async {
    final q = _query({'entidad': entidad, 'page': '$page', 'pageSize': '30'});
    final data =
        await _api.get('/api/admin/auditoria?$q') as Map<String, dynamic>;
    return PaginaAdmin.fromJson(data, AdminAuditoria.fromJson);
  }

  /// Cierra sólo el panel; la sesión del usuario sigue abierta.
  void salir() {
    _api.adminToken = null;
    _vence = null;
  }

  // Respuesta de /acceso/verificar o /acceso/clave: guarda token y vencimiento.
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
