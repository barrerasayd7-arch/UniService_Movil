/// Datos de un perfil (los campos que usa Perfil.jsx).
/// Cuando conectes el backend, agrega aquí el `fromJson`.
class Usuario {
  final int id;
  final String nombre;
  final String descripcion;
  final String telefono;
  final String correo;
  final DateTime fechaRegistro;
  final bool conectado;
  final int totalPublicaciones;
  final int totalSeguidores;
  final int totalSiguiendo;
  final double? reputacion; // null = sin calificaciones
  final String universidad;
  final String? avatarUrl; // null = avatar por defecto

  const Usuario({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.telefono,
    required this.correo,
    required this.fechaRegistro,
    required this.conectado,
    required this.totalPublicaciones,
    required this.totalSeguidores,
    required this.totalSiguiendo,
    required this.universidad,
    this.reputacion,
    this.avatarUrl,
  });

  /// "@mariafernandaperez" (nombre en minúsculas y sin espacios).
  String get username {
    final u = nombre.toLowerCase().replaceAll(RegExp(r'\s'), '');
    return '@${u.isEmpty ? 'usuario' : u}';
  }

  String get reputacionTexto =>
      reputacion != null ? '${reputacion!.toStringAsFixed(1)}/5.0' : 'Sin calificaciones';
}

/// 1200 -> "1.2k", 2500000 -> "2.5M" (formatearNumero de Perfil.jsx).
String formatearNumero(int n) {
  if (n <= 0) return '0';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}k';
  return '$n';
}
