// Archivo: solicitudes_repository.dart
// Responsabilidad: ciclo de vida de solicitudes cliente↔proveedor (crear, listar y
//   cambiar estado) y reseñas del servicio.
// Se usa desde: pantallas de solicitudes, detalle de servicio y perfil.
import 'package:flutter/foundation.dart';

import '../models/solicitud.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Solicitudes entre cliente y proveedor (`/api/solicitudes`) y reseñas (`/api/calificaciones`).
class SolicitudesRepository {
  SolicitudesRepository([ApiClient? api])
    : _api = api ?? AuthRepository.instance.api;

  static final SolicitudesRepository instance = SolicitudesRepository();

  final ApiClient _api;

  /// Aumenta con cada solicitud creada o cambio de estado, para recargar las listas.
  final ValueNotifier<int> cambios = ValueNotifier(0);

  /// Crea la solicitud y abre (o reutiliza) el chat con el proveedor.
  Future<void> crear({
    required int idServicio,
    required String descripcion,
    required int presupuesto,
    DateTime? fechaDeseada,
    String? horaDeseada, // "HH:mm"
    Map<String, String> campos = const {},
  }) async {
    await _api.post('/api/solicitudes', {
      'id_servicio': idServicio,
      'descripcion': descripcion.trim(),
      'presupuesto': presupuesto,
      'fecha_deseada': fechaDeseada == null ? null : fechaIso(fechaDeseada),
      'hora_deseada': horaDeseada,
      if (campos.isNotEmpty) 'campos': campos,
    });
    cambios.value++;
  }

  /// Solicitudes que hice como cliente.
  Future<List<Solicitud>> enviadas() => _listar('enviadas');

  /// Solicitudes que recibí como proveedor.
  Future<List<Solicitud>> recibidas() => _listar('recibidas');

  Future<List<Solicitud>> _listar(String tipo) async {
    final data = await _api.get('/api/solicitudes/$tipo') as List;
    return [for (final s in data) Solicitud.fromJson(s as Map<String, dynamic>)];
  }

  /// Solicitud activa (Pendiente o Aceptada) del usuario para ese servicio, si la hay.
  Future<Solicitud?> activaPara(int idServicio) async {
    for (final s in await enviadas()) {
      if (s.idServicio == idServicio && s.activa) return s;
    }
    return null;
  }

  // Transiciones de estado: el backend valida quién puede ejecutar cada una.
  Future<void> aceptar(int id, {int? contraoferta}) =>
      _transicion(id, 'aceptar', {'contraoferta': contraoferta});
  Future<void> rechazar(int id, String motivo) =>
      _transicion(id, 'rechazar', {'motivo': motivo.trim()});
  Future<void> completar(int id) => _transicion(id, 'completar');
  Future<void> cancelar(int id) => _transicion(id, 'cancelar');

  Future<void> _transicion(int id, String accion, [Object? body]) async {
    await _api.post('/api/solicitudes/$id/$accion', body);
    cambios.value++;
  }

  // ── Reseñas ──

  /// Indica si el usuario ya puede calificar [idServicio] (tras completar la solicitud).
  Future<EstadoCalificacion> estadoCalificacion(int idServicio) async {
    final data = await _api.get(
      '/api/calificaciones/estado?id_servicio=$idServicio',
    );
    return EstadoCalificacion.fromJson(data as Map<String, dynamic>);
  }

  /// Crea la reseña; el servidor recalcula el promedio del servicio.
  Future<void> calificar(int idServicio, int puntuacion, String comentario) =>
      _api.post('/api/calificaciones', {
        'id_servicio': idServicio,
        'puntuacion': puntuacion,
        'comentario': comentario.trim(),
      });

  /// Edita una reseña propia ya publicada.
  Future<void> editarCalificacion(int id, int puntuacion, String comentario) =>
      _api.put('/api/calificaciones/$id', {
        'puntuacion': puntuacion,
        'comentario': comentario.trim(),
      });
}

/// 2026-11-05 -> "2026-11-05" (fecha sin hora, como la espera la API).
String fechaIso(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
