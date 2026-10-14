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

  bool get esAdmin => idRol == 1;

  factory AuthUser.fromJson(Map<String, dynamic> json) => AuthUser(
    id: (json['id'] as num).toInt(),
    nombre: (json['nombre'] as String?) ?? '',
    correo: (json['correo'] as String?) ?? '',
    idRol: (json['id_rol'] as num?)?.toInt() ?? 2,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'nombre': nombre,
    'correo': correo,
    'id_rol': idRol,
  };
}
