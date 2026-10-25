// Archivo: servicio.dart
// Responsabilidad: modelo de tarjeta de servicio, página paginada y lectores tolerantes de JSON.
// Se usa desde: repositorios y pantallas de listado/detalle; otros modelos reutilizan sus lectores.

/// Servicio tal como lo muestran las tarjetas (fila de `GET /api/servicios`).
class Servicio {
  final int id;
  final int idProveedor;
  final String titulo;
  final String descripcion;
  final int? idCategoria;
  final String categoria; // nombre de la categoría
  final String? universidad;
  final String proveedor;
  final int precio; // COP por [unidadPrecio]
  final String unidadPrecio; // 'hora' | 'mes' | 'proyecto'
  final String modalidad; // 'presencial' | 'virtual' | 'mixta'
  final String disponibilidad; // 'entre_semana' | 'fines_de_semana' | 'siempre'
  final double estrellas; // promedio 0..5
  final int numResenas;
  final DateTime fechaPublicacion;
  final String? imagenUrl; // portada (orden 0); null = sin fotos
  final String? avatarProveedor;

  const Servicio({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.proveedor,
    required this.precio,
    required this.estrellas,
    required this.numResenas,
    required this.fechaPublicacion,
    this.idProveedor = 0,
    this.idCategoria,
    this.universidad,
    this.unidadPrecio = 'hora',
    this.modalidad = 'presencial',
    this.disponibilidad = 'siempre',
    this.imagenUrl,
    this.avatarProveedor,
  });

  /// La API entrega `promedio` e `imagen`; aquí se exponen como [estrellas] e [imagenUrl].
  factory Servicio.fromJson(Map<String, dynamic> j) => Servicio(
    id: leerInt(j['id_servicio']),
    idProveedor: leerInt(j['id_proveedor']),
    titulo: (j['titulo'] as String?) ?? '',
    descripcion: (j['descripcion'] as String?) ?? '',
    idCategoria: (j['id_categoria'] as num?)?.toInt(),
    categoria: (j['categoria'] as String?) ?? '',
    universidad: j['universidad'] as String?,
    proveedor: (j['proveedor'] as String?) ?? '',
    precio: leerInt(j['precio']),
    unidadPrecio: (j['unidad_precio'] as String?) ?? 'hora',
    modalidad: (j['modalidad'] as String?) ?? 'presencial',
    disponibilidad: (j['disponibilidad'] as String?) ?? 'siempre',
    estrellas: leerDouble(j['promedio']),
    numResenas: leerInt(j['num_resenas']),
    fechaPublicacion: leerFecha(j['fecha_publicacion']) ?? DateTime(2000),
    imagenUrl: j['imagen'] as String?,
    avatarProveedor: j['avatar'] as String?,
  );
}

/// Página del listado: `{ servicios, pagina, por_pagina, total, total_paginas }`.
class PaginaServicios {
  final List<Servicio> servicios;
  final int pagina;
  final int total;
  final int totalPaginas;
  const PaginaServicios({
    required this.servicios,
    required this.pagina,
    required this.total,
    required this.totalPaginas,
  });

  /// true mientras haya una página siguiente que pedir.
  bool get hayMas => pagina < totalPaginas;

  factory PaginaServicios.fromJson(Map<String, dynamic> j) => PaginaServicios(
    servicios: [
      for (final s in (j['servicios'] as List? ?? const []))
        Servicio.fromJson(s as Map<String, dynamic>),
    ],
    pagina: leerInt(j['pagina'], 1),
    total: leerInt(j['total']),
    totalPaginas: leerInt(j['total_paginas']),
  );
}

// ── Lectura tolerante del JSON (los decimales de Postgres llegan como 650000.00) ──

/// Convierte num o string numérico a int sin lanzar; usa [porDefecto] si no se puede.
int leerInt(Object? v, [int porDefecto = 0]) =>
    v is num ? v.round() : int.tryParse('$v') ?? porDefecto;

/// Igual que [leerInt] pero conserva decimales (el precio llega como 650000.00).
double leerDouble(Object? v) =>
    v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

/// Fecha ISO de la API (UTC) en hora local; null si falta o no es válida.
DateTime? leerFecha(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;
