// Archivo: perfil_repository.dart
// Responsabilidad: perfil propio y público, avatar, seguidores, inicio de chat y reportes.
// Se usa desde: pantallas de perfil, detalle de servicio y chat.
import '../models/usuario.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Perfil, seguidores y reportes contra /api/perfil y /api/reportes.
/// El servidor identifica al usuario por el token: nunca se envía "mi id".
class PerfilRepository {
  PerfilRepository._(this._api);
  static final PerfilRepository instance = PerfilRepository._(AuthRepository.instance.api);

  final ApiClient _api;

  /// Mi perfil completo (con correo y teléfono).
  Future<Usuario> miPerfil() async =>
      Usuario.fromJson(await _api.get('/api/perfil/me') as Map<String, dynamic>);

  /// Perfil público de otra persona (sin datos de contacto).
  Future<Usuario> perfil(int id) async =>
      Usuario.fromJson(await _api.get('/api/perfil/$id') as Map<String, dynamic>);

  /// Cambia sólo los campos indicados; devuelve el perfil actualizado.
  /// Campos: nombre, descripcion, telefono, programa, semestre, sede, disponibilidad, portafolio_url.
  Future<Usuario> actualizar(Map<String, Object?> campos) async =>
      Usuario.fromJson(await _api.put('/api/perfil/me', campos) as Map<String, dynamic>);

  /// Sube la foto (JPG, PNG o WebP, máx. 2 MB). El servidor le quita la ubicación GPS. Devuelve la URL.
  Future<String> subirAvatar(List<int> bytes, String nombre) async {
    final data = await _api.subirArchivos('/api/perfil/me/avatar', 'avatar', [(bytes: bytes, nombre: nombre)]);
    return (data as Map)['avatar'] as String;
  }

  /// Borra la foto; el perfil vuelve al avatar por defecto.
  Future<void> quitarAvatar() => _api.delete('/api/perfil/me/avatar');

  /// Devuelve el nuevo total de seguidores de [id].
  Future<int> seguir(int id, {required bool seguir}) async {
    final data = seguir ? await _api.post('/api/perfil/$id/seguir') : await _api.delete('/api/perfil/$id/seguir');
    return ((data as Map)['total_seguidores'] as num).toInt();
  }

  // Listas sociales limitadas a 50 para no paginar en la primera versión.
  Future<List<PersonaResumen>> seguidores(int id) => _lista('/api/perfil/$id/seguidores?tamano=50');
  Future<List<PersonaResumen>> siguiendo(int id) => _lista('/api/perfil/$id/siguiendo?tamano=50');

  Future<List<PersonaResumen>> _lista(String path) async {
    final data = await _api.get(path) as Map<String, dynamic>;
    return [for (final p in data['items'] as List) PersonaResumen.fromJson(p as Map<String, dynamic>)];
  }

  /// Crea (o recupera) el chat con [idUsuario]. Devuelve su id.
  Future<int> iniciarChat(int idUsuario) async {
    final data = await _api.post('/api/chat/iniciar', {'id_usuario': idUsuario});
    return ((data as Map)['id_chat'] as num).toInt();
  }

  /// Reporta a un usuario o servicio. [tipo] es el motivo (p. ej. 'usuario'/'servicio').
  Future<void> reportar({
    required String tipo,
    required String titulo,
    required String descripcion,
    int? idUsuarioReportado,
    int? idServicio,
  }) => _api.post('/api/reportes', {
    'tipo_reporte': tipo,
    'titulo': titulo,
    'descripcion': descripcion,
    'id_usuario_reportado': ?idUsuarioReportado,
    'id_servicio': ?idServicio,
  });
}
