// Archivo: auth_user.dart
// Responsabilidad: identidad mínima de la sesión (id, nombre, correo y rol) que se persiste localmente.
// Se usa desde: AuthRepository (login, registro y restauración de sesión).

/// Usuario de la sesión actual, tal como lo devuelven /api/auth/login y /register.
class AuthUser {
  final int id;
  final String nombre;
  final String correo;
  final int idRol; // 1 = administrador, 2 = usuario

  const AuthUser({
    required this.id,
    required this.nombre,
    required this.correo,
    required this.idRol,
  });

  /// true para administradores (id_rol 1); el resto son usuarios normales.
  bool get esAdmin => idRol == 1;

  /// Tolerante a campos ausentes: nombre/correo vacíos y rol 2 por defecto.
  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    nombre: (json['nombre'] as String?) ?? '',
    correo: (json['correo'] as String?) ?? '',
    idRol: (json['id_rol'] as num?)?.toInt() ?? 2,
  );

  /// Forma con la que se guarda la sesión en almacenamiento local.
  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'id_rol': idRol,
  };
}
