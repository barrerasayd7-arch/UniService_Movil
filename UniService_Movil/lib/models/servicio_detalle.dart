// Archivo: servicio_detalle.dart
// Responsabilidad: detalle completo de un servicio (proveedor, reseñas, galería, contacto) y utilidades de presentación.
// Se usa desde: DetailScreen y el repositorio de detalle.

import 'servicio.dart';

/// Reseña de un cliente.
class Resena {
  final int id;
  final int idCliente;
  final String autor;
  final String? avatar;
  final DateTime? fecha;
  final int estrellas;
  final String comentario;
  final bool editada;
  const Resena({
    required this.autor,
    required this.fecha,
    required this.estrellas,
    required this.comentario,
    this.id = 0,
    this.idCliente = 0,
    this.avatar,
    this.editada = false,
  });

  factory Resena.fromJson(Map<String, dynamic> j) => Resena(
    id: leerInt(j['id_calificacion']),
    idCliente: leerInt(j['id_cliente']),
    autor: (j['autor'] as String?) ?? '',
    avatar: j['avatar'] as String?,
    fecha: leerFecha(j['fecha']),
    estrellas: leerInt(j['puntuacion']).clamp(1, 5),
    comentario: (j['comentario'] as String?) ?? '',
    editada: j['editada'] == true,
  );
}

/// Imagen de la galería. Si [url] es null se dibuja un marcador con el ícono de la categoría.
class ImagenServicio {
  final int id;
  final String? url;
  final int tono; // solo para variar el color del marcador
  const ImagenServicio({this.id = 0, this.url, this.tono = 0});

  factory ImagenServicio.fromJson(Map<String, dynamic> j) =>
      ImagenServicio(id: leerInt(j['id_imagen']), url: j['url'] as String?);
}

/// Quien ofrece el servicio, con sus estadísticas en todos sus servicios.
class ProveedorResumen {
  final int id;
  final String nombre;
  final String? universidad;
  final String? avatar;
  final int serviciosPublicados;
  final int numResenas;
  final double promedio;
  const ProveedorResumen({
    required this.id,
    required this.nombre,
    this.universidad,
    this.avatar,
    this.serviciosPublicados = 0,
    this.numResenas = 0,
    this.promedio = 0,
  });

  factory ProveedorResumen.fromJson(Map<String, dynamic> j) => ProveedorResumen(
    id: leerInt(j['id_usuario']),
    nombre: (j['nombre'] as String?) ?? '',
    universidad: j['universidad'] as String?,
    avatar: j['avatar'] as String?,
    serviciosPublicados: leerInt(j['servicios_publicados']),
    numResenas: leerInt(j['num_resenas']),
    promedio: leerDouble(j['promedio']),
  );
}

/// Detalle de `GET /api/servicios/{id}`.
/// Sin sesión, [contacto], [direccion] y las coordenadas llegan null.
class ServicioDetalle {
  final Servicio servicio;
  final ProveedorResumen proveedor;
  final String estado; // pendiente | aprobado | pausado | rechazado
  final String? motivoRechazo; // sólo lo ve el dueño
  final bool esPropio;
  final String? contacto; // correo o teléfono
  final String? direccion;
  final double? lat;
  final double? lng;
  final bool tieneUbicacion;
  final List<Resena> resenas;
  final List<ImagenServicio> imagenes;
  final int numResenas;
  final double promedio;

  const ServicioDetalle({
    required this.servicio,
    required this.proveedor,
    required this.resenas,
    required this.imagenes,
    this.estado = 'aprobado',
    this.motivoRechazo,
    this.esPropio = false,
    this.contacto,
    this.direccion,
    this.lat,
    this.lng,
    this.tieneUbicacion = false,
    int? numResenas,
    double? promedio,
  }) : numResenas = numResenas ?? resenas.length,
       promedio = promedio ?? 0;

  /// Anida el servicio con los datos del proveedor y la galería; sin sesión,
  /// contacto, dirección y coordenadas llegan null.
  factory ServicioDetalle.fromJson(Map<String, dynamic> j) {
    final s = j['servicio'] as Map<String, dynamic>;
    final p = ProveedorResumen.fromJson(s['proveedor'] as Map<String, dynamic>);
    final numResenas = leerInt(j['num_resenas']);
    final promedio = leerDouble(j['promedio']);
    final imagenes = [
      for (final i in (j['imagenes'] as List? ?? const []))
        ImagenServicio.fromJson(i as Map<String, dynamic>),
    ];
    return ServicioDetalle(
      servicio: Servicio(
        id: leerInt(s['id_servicio']),
        idProveedor: p.id,
        titulo: (s['titulo'] as String?) ?? '',
        descripcion: (s['descripcion'] as String?) ?? '',
        idCategoria: (s['id_categoria'] as num?)?.toInt(),
        categoria: (s['categoria'] as String?) ?? '',
        universidad: p.universidad,
        proveedor: p.nombre,
        precio: leerInt(s['precio']),
        unidadPrecio: (s['unidad_precio'] as String?) ?? 'hora',
        modalidad: (s['modalidad'] as String?) ?? 'presencial',
        disponibilidad: (s['disponibilidad'] as String?) ?? 'siempre',
        estrellas: promedio,
        numResenas: numResenas,
        fechaPublicacion: leerFecha(s['fecha_publicacion']) ?? DateTime(2000),
        imagenUrl: imagenes.isEmpty ? null : imagenes.first.url,
        avatarProveedor: p.avatar,
      ),
      proveedor: p,
      estado: (s['estado'] as String?) ?? 'aprobado',
      motivoRechazo: s['motivo_rechazo'] as String?,
      esPropio: s['es_propio'] == true,
      contacto: s['contacto'] as String?,
      direccion: s['direccion'] as String?,
      lat: (s['ubicacion_lat'] as num?)?.toDouble(),
      lng: (s['ubicacion_lng'] as num?)?.toDouble(),
      tieneUbicacion: s['tiene_ubicacion'] == true,
      resenas: [
        for (final r in (j['resenas'] as List? ?? const []))
          Resena.fromJson(r as Map<String, dynamic>),
      ],
      imagenes: imagenes,
      numResenas: numResenas,
      promedio: promedio,
    );
  }

  /// Los arriendos cambian la UI (precio mensual y ubicación) frente al resto.
  bool get esArriendo => servicio.categoria.toLowerCase().contains('arriendo');

  /// Universidad ya normalizada para mostrar en la ficha.
  String get universidadTexto => textoUniversidad(servicio.universidad);
}

/// Universidad para mostrar ("Sin universidad" de la BD se lee como "Independiente").
String textoUniversidad(String? u) {
  if (u == null || u.trim().isEmpty) return 'Comunidad académica';
  if (u == 'No pertenece a ninguna universidad' || u == 'Sin universidad') {
    return 'Independiente';
  }
  return u;
}

/// "María Fernanda" -> "MF".
String iniciales(String? nombre) {
  if (nombre == null || nombre.trim().isEmpty) return '?';
  final partes = nombre.trim().split(RegExp(r'\s+'));
  return partes
      .map((p) => p[0])
      .join()
      .toUpperCase()
      .substring(0, partes.length >= 2 ? 2 : 1);
}
