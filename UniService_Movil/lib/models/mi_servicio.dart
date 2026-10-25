// Archivo: mi_servicio.dart
// Responsabilidad: servicio propio con su estado de moderación y métricas para "Mis servicios".
// Se usa desde: MisServiciosScreen y el repositorio de servicios del usuario.

import 'servicio.dart';

/// Servicio propio, en cualquier estado (`GET /api/servicios/mios`).
class MiServicio {
  final int id;
  final String titulo;
  final String estado; // pendiente | aprobado | pausado | rechazado
  final String? motivoRechazo;
  final int precio;
  final String unidadPrecio;
  final String categoria;
  final DateTime? fechaPublicacion;
  final String? imagenUrl;
  final int numImagenes;
  final int numResenas;
  final double promedio;
  final int solicitudesPendientes;

  const MiServicio({
    required this.id,
    required this.titulo,
    required this.estado,
    required this.precio,
    required this.unidadPrecio,
    required this.categoria,
    this.motivoRechazo,
    this.fechaPublicacion,
    this.imagenUrl,
    this.numImagenes = 0,
    this.numResenas = 0,
    this.promedio = 0,
    this.solicitudesPendientes = 0,
  });

  /// Mapea la fila de `GET /api/servicios/mios`; los contadores vienen ya agregados.
  factory MiServicio.fromJson(Map<String, dynamic> j) => MiServicio(
    id: leerInt(j['id_servicio']),
    titulo: (j['titulo'] as String?) ?? '',
    estado: (j['estado'] as String?) ?? 'pendiente',
    motivoRechazo: j['motivo_rechazo'] as String?,
    precio: leerInt(j['precio']),
    unidadPrecio: (j['unidad_precio'] as String?) ?? 'hora',
    categoria: (j['categoria'] as String?) ?? '',
    fechaPublicacion: leerFecha(j['fecha_publicacion']),
    imagenUrl: j['imagen'] as String?,
    numImagenes: leerInt(j['num_imagenes']),
    numResenas: leerInt(j['num_resenas']),
    promedio: leerDouble(j['promedio']),
    solicitudesPendientes: leerInt(j['solicitudes_pendientes']),
  );

  /// Solo se puede pausar lo que está publicado.
  bool get puedePausar => estado == 'aprobado';
  /// Solo se puede reanudar lo que está pausado.
  bool get puedeReanudar => estado == 'pausado';
}
