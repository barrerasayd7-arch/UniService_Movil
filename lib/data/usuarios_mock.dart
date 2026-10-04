import '../models/usuario.dart';

/// Perfil propio de ejemplo (en la web: GET /api/users/{id}).
final Usuario miPerfilMock = Usuario(
  id: 1,
  nombre: 'Sayd Barrera',
  descripcion:
      'Estudiante de Ingeniería de Sistemas. Ofrezco tutorías de programación y desarrollo de apps móviles.',
  telefono: '3001234567',
  correo: 'sayd.barr@unicesar.edu.co',
  fechaRegistro: DateTime(2025, 3, 14),
  conectado: true,
  totalPublicaciones: 5,
  totalSeguidores: 1280,
  totalSiguiendo: 42,
  universidad: 'Universidad Popular del Cesar',
  reputacion: 4.8,
);

/// Perfil de otra persona (para ver la vista de perfil externo).
final Usuario perfilExternoMock = Usuario(
  id: 2,
  nombre: 'sayd Gómez',
  descripcion:
      'Redacto ensayos y corrijo textos académicos con normas APA. Entrega rápida y revisión incluida.',
  telefono: 'No disponible',
  correo: 'sayd.gomez@correo.com',
  fechaRegistro: DateTime(2025, 6, 2),
  conectado: false,
  totalPublicaciones: 3,
  totalSeguidores: 87,
  totalSiguiendo: 15,
  universidad: 'Sin universidad',
);

/// Lista de ejemplo para los modales de seguidores / siguiendo.
class PersonaLista {
  final String nombre;
  final String universidad;
  const PersonaLista(this.nombre, this.universidad);
}

const List<PersonaLista> personasMock = [
  PersonaLista('María Fernanda Pérez', 'Universidad Popular del Cesar'),
  PersonaLista('Juan David Torres', 'Sin universidad'),
  PersonaLista('Daniela Castro', 'Universidad Popular del Cesar'),
  PersonaLista('Sebastián Mejía', 'Universidad de Santander'),
  PersonaLista('Valentina Ortiz', 'Sin universidad'),
];
