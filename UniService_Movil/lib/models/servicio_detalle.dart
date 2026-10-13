import 'servicio.dart';

/// Reseña de un cliente (campos que usa DetalleServicio.jsx).
class Resena {
  final String autor;
  final String fecha;
  final int estrellas;
  final String comentario;
  const Resena({
    required this.autor,
    required this.fecha,
    required this.estrellas,
    required this.comentario,
  });
}

/// Imagen de la galería. Si [url] es null se dibuja un marcador de ejemplo.
class ImagenServicio {
  final String? url;
  final int tono; // solo para variar el color del marcador
  const ImagenServicio({this.url, this.tono = 0});
}

/// Servicio con todos los datos de la vista de detalle.
/// Cuando conectes el backend, agrega aquí el `fromJson` (GET /api/services/{id}).
class ServicioDetalle {
  final Servicio servicio;
  final String modalidad; // Presencial | Virtual | Mixta
  final String disponibilidad; // Entre semana | Fines de semana | Siempre disponible
  final String? contacto; // correo o teléfono
  final String? direccion;
  final bool tieneUbicacion;
  final List<Resena> resenas;
  final List<ImagenServicio> imagenes;

  const ServicioDetalle({
    required this.servicio,
    required this.modalidad,
    required this.disponibilidad,
    required this.resenas,
    required this.imagenes,
    this.contacto,
    this.direccion,
    this.tieneUbicacion = false,
  });

  /// Copia con otra lista de reseñas (al publicar una reseña nueva).
  ServicioDetalle conResenas(List<Resena> nuevas) => ServicioDetalle(
        servicio: servicio,
        modalidad: modalidad,
        disponibilidad: disponibilidad,
        contacto: contacto,
        direccion: direccion,
        tieneUbicacion: tieneUbicacion,
        resenas: nuevas,
        imagenes: imagenes,
      );

  bool get esArriendo => servicio.categoria.toLowerCase().contains('arriendo');

  /// Promedio calculado desde las reseñas (calcularEstrellas de helpers.js).
  double get promedio {
    if (resenas.isEmpty) return 0;
    final suma = resenas.fold<int>(0, (a, r) => a + r.estrellas);
    return (suma / resenas.length).clamp(0.0, 5.0).toDouble();
  }

  String get universidadTexto {
    final u = servicio.universidad;
    if (u == null || u.isEmpty) return 'Comunidad académica';
    if (u == 'No pertenece a ninguna universidad') return 'Independiente';
    return u;
  }
}

/// "María Fernanda" -> "MF" (iniciales de helpers.js).
String iniciales(String? nombre) {
  if (nombre == null || nombre.trim().isEmpty) return '?';
  final partes = nombre.trim().split(RegExp(r'\s+'));
  return partes.map((p) => p[0]).join().toUpperCase().substring(
        0,
        partes.length >= 2 ? 2 : 1,
      );
}
