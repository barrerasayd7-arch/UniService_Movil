// Archivo: solicitud.dart
// Responsabilidad: solicitud entre cliente y proveedor, sus estados y el estado de calificación.
// Se usa desde: pantallas de solicitudes y el repositorio de solicitudes.

import 'servicio.dart';

/// Persona en una solicitud (cliente o proveedor).
class ParteSolicitud {
  final int id;
  final String nombre;
  final String? avatar;
  const ParteSolicitud({required this.id, required this.nombre, this.avatar});

  factory ParteSolicitud.fromJson(Map<String, dynamic> j) => ParteSolicitud(
    id: leerInt(j['id_usuario']),
    nombre: (j['nombre'] as String?) ?? '',
    avatar: j['avatar'] as String?,
  );
}

/// Fila de `GET /api/solicitudes/enviadas|recibidas`.
/// Estados: Pendiente → Aceptada → Completada, Pendiente → Rechazada,
/// y el cliente puede pasar Pendiente o Aceptada a Cancelada.
class Solicitud {
  final int id;
  final String estado;
  final String rol; // 'cliente' | 'proveedor' (el del usuario actual)
  final String descripcion;
  final int? presupuesto;
  final int? contraoferta;
  final String? motivoRechazo;
  final DateTime? fechaDeseada;
  final String? horaDeseada; // "HH:mm"
  final Map<String, String> campos;
  final DateTime? fechaCreacion;
  final int idServicio;
  final String tituloServicio;
  final String categoria;
  final String? imagenServicio;
  final ParteSolicitud cliente;
  final ParteSolicitud proveedor;
  final bool puedeCalificar;
  final int? idCalificacion;

  const Solicitud({
    required this.id,
    required this.estado,
    required this.rol,
    required this.descripcion,
    required this.idServicio,
    required this.tituloServicio,
    required this.categoria,
    required this.cliente,
    required this.proveedor,
    this.presupuesto,
    this.contraoferta,
    this.motivoRechazo,
    this.fechaDeseada,
    this.horaDeseada,
    this.campos = const {},
    this.fechaCreacion,
    this.imagenServicio,
    this.puedeCalificar = false,
    this.idCalificacion,
  });

  factory Solicitud.fromJson(Map<String, dynamic> j) {
    final s = j['servicio'] as Map<String, dynamic>? ?? const {};
    final campos = j['campos'];
    final fecha = j['fecha_deseada'];
    return Solicitud(
      id: leerInt(j['id_solicitud']),
      estado: (j['estado'] as String?) ?? 'Pendiente',
      rol: (j['rol'] as String?) ?? 'cliente',
      descripcion: (j['descripcion'] as String?) ?? '',
      presupuesto: (j['presupuesto'] as num?)?.round(),
      contraoferta: (j['contraoferta'] as num?)?.round(),
      motivoRechazo: j['motivo_rechazo'] as String?,
      // "2026-11-20": fecha sin hora, no se convierte de zona horaria.
      fechaDeseada: fecha is String ? DateTime.tryParse(fecha) : null,
      horaDeseada: j['hora_deseada'] as String?,
      campos: campos is Map
          ? {for (final e in campos.entries) '${e.key}': '${e.value}'}
          : const {},
      fechaCreacion: leerFecha(j['fecha_creacion']),
      idServicio: leerInt(s['id_servicio']),
      tituloServicio: (s['titulo'] as String?) ?? '',
      categoria: (s['categoria'] as String?) ?? '',
      imagenServicio: s['imagen'] as String?,
      cliente: ParteSolicitud.fromJson(
        j['cliente'] as Map<String, dynamic>? ?? const {},
      ),
      proveedor: ParteSolicitud.fromJson(
        j['proveedor'] as Map<String, dynamic>? ?? const {},
      ),
      puedeCalificar: j['puede_calificar'] == true,
      idCalificacion: (j['id_calificacion'] as num?)?.toInt(),
    );
  }

  bool get soyCliente => rol == 'cliente';
  /// Sigue en curso: ni terminada, ni rechazada, ni cancelada.
  bool get activa => estado == 'Pendiente' || estado == 'Aceptada';

  /// La otra persona de la solicitud.
  ParteSolicitud get contraparte => soyCliente ? proveedor : cliente;

  // Permisos derivados del rol y del estado; la UI muestra los botones según estos.
  bool get puedeAceptar => !soyCliente && estado == 'Pendiente';
  bool get puedeRechazar => !soyCliente && estado == 'Pendiente';
  bool get puedeCompletar => !soyCliente && estado == 'Aceptada';
  bool get puedeCancelar => soyCliente && activa;
}

/// `GET /api/calificaciones/estado?id_servicio=`.
class EstadoCalificacion {
  final bool puedeCalificar;
  final int? idCalificacion;
  final int puntuacion;
  final String comentario;
  final DateTime? fecha;

  const EstadoCalificacion({
    required this.puedeCalificar,
    this.idCalificacion,
    this.puntuacion = 0,
    this.comentario = '',
    this.fecha,
  });

  /// Estado sin calificación ni permiso, para inicializar la UI.
  static const ninguno = EstadoCalificacion(puedeCalificar: false);

  /// true si el usuario ya dejó una reseña para este servicio.
  bool get yaCalifico => idCalificacion != null;

  factory EstadoCalificacion.fromJson(Map<String, dynamic> j) {
    final mia = j['mi_calificacion'] as Map<String, dynamic>?;
    return EstadoCalificacion(
      puedeCalificar: j['puede_calificar'] == true,
      idCalificacion: (mia?['id_calificacion'] as num?)?.toInt(),
      puntuacion: leerInt(mia?['puntuacion']),
      comentario: (mia?['comentario'] as String?) ?? '',
      fecha: leerFecha(mia?['fecha']),
    );
  }
}
