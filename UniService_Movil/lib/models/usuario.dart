/// Perfil de un usuario tal como lo devuelve la API:
///  - GET /api/perfil/me  → el propio, con [correo] y [telefono].
///  - GET /api/perfil/{id} → el público de otra persona: sin correo ni teléfono
///    (llegan null), y con [loSigo] / [esMio].
class Usuario {
  final int id;
  final String nombre;
  final String descripcion;
  final String? avatarUrl; // null = avatar por defecto
  final String universidad;
  final DateTime? fechaRegistro;

  // Sólo en el perfil propio.
  final String? correo;
  final String? telefono;
  final bool correoVerificado;

  // Perfil académico (declarado por el usuario).
  final String programa;
  final int? semestre;
  final String sede;
  final String disponibilidad;
  final String? portafolioUrl;

  final int totalPublicaciones;
  final int totalSeguidores;
  final int totalSiguiendo;
  final double? reputacion; // null = sin calificaciones
  final int totalCalificaciones;

  // Sólo en el perfil público.
  final bool loSigo;
  final bool esMio;

  const Usuario({
    required this.id,
    required this.nombre,
    this.descripcion = '',
    this.avatarUrl,
    this.universidad = '',
    this.fechaRegistro,
    this.correo,
    this.telefono,
    this.correoVerificado = false,
    this.programa = '',
    this.semestre,
    this.sede = '',
    this.disponibilidad = '',
    this.portafolioUrl,
    this.totalPublicaciones = 0,
    this.totalSeguidores = 0,
    this.totalSiguiendo = 0,
    this.reputacion,
    this.totalCalificaciones = 0,
    this.loSigo = false,
    this.esMio = false,
  });

  factory Usuario.fromJson(Map<String, dynamic> j) {
    final academico = (j['perfil_academico'] as Map?)?.cast<String, dynamic>() ?? const {};
    final stats = (j['estadisticas'] as Map?)?.cast<String, dynamic>() ?? const {};
    int entero(Object? v) => (v as num?)?.toInt() ?? 0;
    return Usuario(
      id: (j['id'] as num).toInt(),
      nombre: (j['nombre'] as String?) ?? '',
      descripcion: (j['descripcion'] as String?) ?? '',
      avatarUrl: j['avatar'] as String?,
      universidad: (j['universidad'] as String?) ?? '',
      fechaRegistro: DateTime.tryParse((j['fecha_registro'] as String?) ?? '')?.toLocal(),
      correo: j['correo'] as String?,
      telefono: j['telefono'] as String?,
      correoVerificado: j['correo_verificado'] == true,
      programa: (academico['programa'] as String?) ?? '',
      semestre: (academico['semestre'] as num?)?.toInt(),
      sede: (academico['sede'] as String?) ?? '',
      disponibilidad: (academico['disponibilidad'] as String?) ?? '',
      portafolioUrl: academico['portafolio_url'] as String?,
      totalPublicaciones: entero(stats['servicios']),
      totalSeguidores: entero(stats['seguidores']),
      totalSiguiendo: entero(stats['siguiendo']),
      reputacion: (stats['calificacion_promedio'] as num?)?.toDouble(),
      totalCalificaciones: entero(stats['total_calificaciones']),
      loSigo: j['lo_sigo'] == true,
      esMio: j['es_mio'] == true,
    );
  }

  Usuario copyWith({String? avatarUrl, bool quitarAvatar = false, bool? loSigo, int? totalSeguidores}) => Usuario(
    id: id, nombre: nombre, descripcion: descripcion,
    avatarUrl: quitarAvatar ? null : (avatarUrl ?? this.avatarUrl),
    universidad: universidad, fechaRegistro: fechaRegistro, correo: correo, telefono: telefono,
    correoVerificado: correoVerificado, programa: programa, semestre: semestre, sede: sede,
    disponibilidad: disponibilidad, portafolioUrl: portafolioUrl, totalPublicaciones: totalPublicaciones,
    totalSeguidores: totalSeguidores ?? this.totalSeguidores, totalSiguiendo: totalSiguiendo,
    reputacion: reputacion, totalCalificaciones: totalCalificaciones,
    loSigo: loSigo ?? this.loSigo, esMio: esMio,
  );

  /// "@mariafernandaperez" (nombre en minúsculas y sin espacios).
  String get username {
    final u = nombre.toLowerCase().replaceAll(RegExp(r'\s'), '');
    return '@${u.isEmpty ? 'usuario' : u}';
  }

  String get reputacionTexto => reputacion != null
      ? '${reputacion!.toStringAsFixed(1)}/5.0 ($totalCalificaciones)'
      : 'Sin calificaciones';
}

/// Persona en las listas de seguidores / siguiendo (GET /api/perfil/{id}/seguidores).
class PersonaResumen {
  final int id;
  final String nombre;
  final String universidad;
  final String? avatarUrl;
  final bool loSigo;

  const PersonaResumen({
    required this.id,
    required this.nombre,
    this.universidad = '',
    this.avatarUrl,
    this.loSigo = false,
  });

  factory PersonaResumen.fromJson(Map<String, dynamic> j) => PersonaResumen(
    id: (j['id'] as num).toInt(),
    nombre: (j['nombre'] as String?) ?? '',
    universidad: (j['universidad'] as String?) ?? '',
    avatarUrl: j['avatar'] as String?,
    loSigo: j['lo_sigo'] == true,
  );
}

/// 1200 -> "1.2k", 2500000 -> "2.5M" (formatearNumero de Perfil.jsx).
String formatearNumero(int n) {
  if (n <= 0) return '0';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
