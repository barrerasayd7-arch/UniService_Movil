import 'servicio.dart' show leerInt, leerFecha;

/// Página de un listado del panel: `{ items, total, page, pageSize }`.
class PaginaAdmin<T> {
  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  const PaginaAdmin({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  bool get hayMas => page * pageSize < total;

  factory PaginaAdmin.fromJson(
    Map<String, dynamic> j,
    T Function(Map<String, dynamic>) convertir,
  ) => PaginaAdmin(
    items: [
      for (final e in (j['items'] as List? ?? const []))
        convertir(e as Map<String, dynamic>),
    ],
    total: leerInt(j['total']),
    page: leerInt(j['page'], 1),
    pageSize: leerInt(j['pageSize'], 20),
  );
}

/// Fila de `GET /api/admin/usuarios`.
class AdminUsuario {
  final int id;
  final String nombre;
  final String correo;
  final int rol; // 1 = administrador
  final bool activa;
  final DateTime? fechaRegistro;
  final String? motivoSuspension;
  final int totalServicios;
  final int reportesRecibidos;

  const AdminUsuario({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.rol,
    required this.activa,
    this.fechaRegistro,
    this.motivoSuspension,
    this.totalServicios = 0,
    this.reportesRecibidos = 0,
  });

  bool get esAdmin => rol == 1;

  factory AdminUsuario.fromJson(Map<String, dynamic> j) => AdminUsuario(
    id: leerInt(j['id_usuario']),
    nombre: (j['nombre'] as String?) ?? '',
    correo: (j['correo'] as String?) ?? '',
    rol: leerInt(j['id_rol'], 2),
    activa: j['activa'] == true,
    fechaRegistro: leerFecha(j['fecha_registro']),
    motivoSuspension: j['motivo_suspension'] as String?,
    totalServicios: leerInt(j['total_servicios']),
    reportesRecibidos: leerInt(j['reportes_recibidos']),
  );
}

/// Fila de `GET /api/admin/servicios`.
class AdminServicio {
  final int id;
  final String titulo;
  final int precio;
  final String unidadPrecio;
  final String estado; // pendiente | aprobado | pausado | rechazado
  final String? motivoRechazo;
  final DateTime? fechaPublicacion;
  final String categoria;
  final String proveedor;
  final String? correoProveedor;
  final bool proveedorActivo;
  final String? imagen;
  final int reportes;

  const AdminServicio({
    required this.id,
    required this.titulo,
    required this.precio,
    required this.unidadPrecio,
    required this.estado,
    required this.categoria,
    required this.proveedor,
    this.motivoRechazo,
    this.fechaPublicacion,
    this.correoProveedor,
    this.proveedorActivo = true,
    this.imagen,
    this.reportes = 0,
  });

  factory AdminServicio.fromJson(Map<String, dynamic> j) => AdminServicio(
    id: leerInt(j['id_servicio']),
    titulo: (j['titulo'] as String?) ?? '',
    precio: leerInt(j['precio_hora']),
    unidadPrecio: (j['unidad_precio'] as String?) ?? 'hora',
    estado: (j['estado'] as String?) ?? 'pendiente',
    motivoRechazo: j['motivo_rechazo'] as String?,
    fechaPublicacion: leerFecha(j['fecha_publicacion']),
    categoria: (j['nombre_categoria'] as String?) ?? '',
    proveedor: (j['proveedor'] as String?) ?? '',
    correoProveedor: j['correo_proveedor'] as String?,
    proveedorActivo: j['proveedor_activo'] != false,
    imagen: j['imagen'] as String?,
    reportes: leerInt(j['reportes']),
  );
}

/// Fila de `GET /api/admin/reportes`.
class AdminReporte {
  final int id;
  final String tipo;
  final String titulo;
  final String descripcion;
  final String
  estado; // Pendiente | En_revision | Resuelto | Rechazado | Cerrado
  final DateTime? fecha;
  final DateTime? fechaResolucion;
  final String? notas;
  final List<String> evidencias;
  final String usuario;
  final String? correoUsuario;
  final String? tituloServicio;
  final String? reportado;
  final String? correoReportado;
  final bool? reportadoActivo;
  final String? adminResponde;

  const AdminReporte({
    required this.id,
    required this.tipo,
    required this.titulo,
    required this.descripcion,
    required this.estado,
    required this.usuario,
    this.fecha,
    this.fechaResolucion,
    this.notas,
    this.evidencias = const [],
    this.correoUsuario,
    this.tituloServicio,
    this.reportado,
    this.correoReportado,
    this.reportadoActivo,
    this.adminResponde,
  });

  factory AdminReporte.fromJson(Map<String, dynamic> j) => AdminReporte(
    id: leerInt(j['id_reporte']),
    tipo: (j['tipo_reporte'] as String?) ?? '',
    titulo: (j['titulo'] as String?) ?? '',
    descripcion: (j['descripcion'] as String?) ?? '',
    estado: (j['estado'] as String?) ?? 'Pendiente',
    fecha: leerFecha(j['fecha_creacion']),
    fechaResolucion: leerFecha(j['fecha_resolucion']),
    notas: j['resolucion_notas'] as String?,
    // La columna guarda URLs separadas por comas (y a veces texto libre).
    evidencias: [
      for (final u in ((j['evidencia'] as String?) ?? '').split(','))
        if (u.trim().startsWith('http')) u.trim(),
    ],
    usuario: (j['nombre_usuario'] as String?) ?? 'Usuario',
    correoUsuario: j['correo_usuario'] as String?,
    tituloServicio: j['titulo_servicio'] as String?,
    reportado: j['nombre_reportado'] as String?,
    correoReportado: j['correo_reportado'] as String?,
    reportadoActivo: j['reportado_activo'] as bool?,
    adminResponde: j['admin_responde'] as String?,
  );
}

/// Fila de `GET /api/admin/auditoria`.
class AdminAuditoria {
  final int id;
  final DateTime? fecha;
  final String accion;
  final String entidad;
  final String? detalle;
  final String admin;

  const AdminAuditoria({
    required this.id,
    required this.accion,
    required this.entidad,
    required this.admin,
    this.fecha,
    this.detalle,
  });

  factory AdminAuditoria.fromJson(Map<String, dynamic> j) => AdminAuditoria(
    id: leerInt(j['id_auditoria']),
    fecha: leerFecha(j['fecha']),
    accion: (j['accion'] as String?) ?? '',
    entidad: (j['entidad'] as String?) ?? '',
    detalle: j['detalle'] as String?,
    admin: (j['admin'] as String?) ?? 'Administrador',
  );
}
