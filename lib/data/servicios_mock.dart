import '../models/servicio.dart';

/// Datos de ejemplo para ver el diseño sin backend.
/// En la web venían de GET /api/services; aquí los reemplazas luego por tu API.
final List<Servicio> serviciosMock = [
  Servicio(
    id: 1,
    titulo: 'Tutoría de Cálculo Diferencial',
    descripcion:
        'Clases personalizadas de límites, derivadas y aplicaciones con ejercicios resueltos paso a paso.',
    categoria: 'Tutorías',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'María Fernanda Pérez',
    precioHora: 20000,
    estrellas: 4.8,
    numResenas: 24,
    fechaPublicacion: DateTime(2026, 9, 28),
  ),
  Servicio(
    id: 2,
    titulo: 'Redacción de ensayos académicos',
    descripcion:
        'Te ayudo a estructurar y redactar ensayos argumentativos con normas APA 7 y revisión de ortografía.',
    categoria: 'Ensayos y redacción',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'Carlos Andrés Gómez',
    precioHora: 15000,
    estrellas: 4.5,
    numResenas: 18,
    fechaPublicacion: DateTime(2026, 9, 26),
  ),
  Servicio(
    id: 3,
    titulo: 'Desarrollo de apps móviles con Flutter',
    descripcion:
        'Construyo tu proyecto de programación móvil: interfaces, navegación, consumo de APIs y buenas prácticas.',
    categoria: 'Programación',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'Sayd Barrera',
    precioHora: 350,
    estrellas: 5.0,
    numResenas: 31,
    fechaPublicacion: DateTime(2026, 9, 25),
  ),
  Servicio(
    id: 4,
    titulo: 'Diseño de logos e identidad visual',
    descripcion:
        'Creo el logo y la paleta de colores para tu emprendimiento o proyecto universitario, con entrega en vectores.',
    categoria: 'Diseño',
    proveedor: 'Juan David Torres',
    precioHora: 30000,
    estrellas: 4.7,
    numResenas: 12,
    fechaPublicacion: DateTime(2026, 9, 22),
  ),
  Servicio(
    id: 5,
    titulo: 'Asesoría para proyecto de grado',
    descripcion:
        'Acompañamiento en la planeación, metodología y presentación de tu anteproyecto y proyecto final.',
    categoria: 'Proyectos',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'Daniela Castro',
    precioHora: 40000,
    estrellas: 4.2,
    numResenas: 9,
    fechaPublicacion: DateTime(2026, 9, 20),
  ),
  Servicio(
    id: 6,
    titulo: 'Habitación amoblada cerca a la universidad',
    descripcion:
        'Habitación con baño privado, wifi y servicios incluidos a 5 minutos caminando de la sede principal.',
    categoria: 'Arriendo de habitaciones',
    proveedor: 'Andrea Villazón',
    precioHora: 450000,
    estrellas: 4.0,
    numResenas: 7,
    fechaPublicacion: DateTime(2026, 9, 18),
  ),
  Servicio(
    id: 7,
    titulo: 'Tutoría de Física Mecánica',
    descripcion:
        'Repaso de cinemática, dinámica y energía con talleres tipo parcial para que llegues preparado.',
    categoria: 'Tutorías',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'Sebastián Mejía',
    precioHora: 18000,
    estrellas: 4.6,
    numResenas: 15,
    fechaPublicacion: DateTime(2026, 9, 15),
  ),
  Servicio(
    id: 8,
    titulo: 'Maquetación de páginas web',
    descripcion:
        'Páginas web responsivas con HTML, CSS y JavaScript para tus trabajos de programación web.',
    categoria: 'Programación',
    proveedor: 'Valentina Ortiz',
    precioHora: 25000,
    estrellas: 4.4,
    numResenas: 11,
    fechaPublicacion: DateTime(2026, 9, 12),
  ),
  Servicio(
    id: 9,
    titulo: 'Diseño de presentaciones y afiches',
    descripcion:
        'Presentaciones profesionales en PowerPoint y Canva para exposiciones, ferias y eventos académicos.',
    categoria: 'Diseño',
    universidad: 'Universidad Popular del Cesar',
    proveedor: 'Miguel Ángel Rojas',
    precioHora: 12000,
    estrellas: 3.9,
    numResenas: 6,
    fechaPublicacion: DateTime(2026, 9, 10),
  ),
  Servicio(
    id: 10,
    titulo: 'Corrección y estilo de textos',
    descripcion:
        'Revisión de coherencia, ortografía y estilo para tesis, artículos, informes y trabajos escritos.',
    categoria: 'Ensayos y redacción',
    proveedor: 'Isabella Martínez',
    precioHora: 10000,
    estrellas: 4.3,
    numResenas: 14,
    fechaPublicacion: DateTime(2026, 9, 5),
  ),
];
