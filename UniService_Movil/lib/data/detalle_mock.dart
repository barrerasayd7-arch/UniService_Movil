import '../models/servicio.dart';
import '../models/servicio_detalle.dart';

/// Genera datos de ejemplo para el detalle a partir de un [Servicio].
/// En la web esto venía de GET /api/services/{id}.
ServicioDetalle detalleMock(Servicio s) {
  const modalidades = ['Presencial', 'Virtual', 'Mixta'];
  const disponibilidades = ['Entre semana', 'Fines de semana', 'Siempre disponible'];

  final esArriendo = s.categoria.toLowerCase().contains('arriendo');

  // Contacto: teléfono (WhatsApp) en ids pares, correo (Gmail) en impares
  final primerNombre = s.proveedor.split(' ').first.toLowerCase();
  final contacto = s.id.isEven ? '30${(10000000 + s.id * 7919).toString().substring(0, 8)}' : '$primerNombre@correo.com';

  // Reseñas de ejemplo con estrellas cercanas al promedio del servicio
  const autores = [
    'Carlos Andrés Gómez',
    'Daniela Castro',
    'Juan David Torres',
    'Valentina Ortiz',
    'Sebastián Mejía',
    'Isabella Martínez',
  ];
  const comentarios = [
    'Excelente servicio, muy puntual y claro en las explicaciones. Lo recomiendo.',
    'Cumplió con todo lo acordado y entregó antes de la fecha. Muy amable.',
    'Buena atención y buen trabajo. Volvería a solicitarlo sin dudarlo.',
    'Me ayudó muchísimo, resolvió todas mis dudas paso a paso.',
    'Todo bien, aunque tardó un poco en responder al inicio.',
    'Muy profesional. Superó lo que esperaba por ese precio.',
  ];
  final base = s.estrellas.round().clamp(1, 5).toInt();
  final cantidad = s.numResenas.clamp(0, 6).toInt();
  final resenas = [
    for (var i = 0; i < cantidad; i++)
      Resena(
        autor: autores[i % autores.length],
        fecha: '${10 + i * 3} de septiembre de 2026',
        estrellas: (i.isOdd ? base - 1 : base).clamp(1, 5).toInt(),
        comentario: comentarios[(i + s.id) % comentarios.length],
      ),
  ];

  // Galería: marcadores de ejemplo (el servicio 1 y los arriendos tienen fotos)
  final imagenes = s.id == 1
      ? const [ImagenServicio(tono: 0), ImagenServicio(tono: 1), ImagenServicio(tono: 2)]
      : esArriendo
          ? const [ImagenServicio(tono: 3), ImagenServicio(tono: 1)]
          : const <ImagenServicio>[];

  return ServicioDetalle(
    servicio: s,
    modalidad: modalidades[s.id % 3],
    disponibilidad: disponibilidades[s.id % 3],
    contacto: contacto,
    direccion: esArriendo ? 'Calle 12 # 8-45, Valledupar' : null,
    tieneUbicacion: esArriendo,
    resenas: resenas,
    imagenes: imagenes,
  );
}
