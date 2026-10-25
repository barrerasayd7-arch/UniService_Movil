// Archivo: categorias.dart
// Responsabilidad: catálogo de categorías (iconos, colores, chips), etiquetas de estado y formato de datos.
// Se usa desde: tarjetas, filtros, formularios y pantallas de detalle.

import 'package:flutter/material.dart';

// Equivalente a shared/constantes.js (iconos, colores y chips de categoría).
// Los iconos de Bootstrap Icons se reemplazan por Material Icons.

/// Par de colores de una categoría: fondo translúcido y color de texto/icono.
class CategoriaColor {
  final Color bg;
  final Color color;
  const CategoriaColor(this.bg, this.color);
}

/// Chip de filtro del home: texto visible, valor de la API e icono; `idCategoria` null = todas.
class ChipCategoria {
  final String label;
  final String valor;
  final IconData icono;
  final int? idCategoria; // null = todas
  const ChipCategoria(this.label, this.valor, this.icono, [this.idCategoria]);
}

/// Categorías de la tabla `categorias` (ids fijos; el backend también usa 6 = arriendo).
const List<(int, String)> categoriasServicio = [
  (1, 'Tutorías'),
  (2, 'Ensayos y redacción'),
  (3, 'Proyectos'),
  (4, 'Programación'),
  (5, 'Diseño'),
  (6, 'Arriendo de habitaciones'),
  (7, 'Otros servicios'),
];

const int idCategoriaArriendo = 6;

/// Icono Material asociado al nombre de categoría (si no hay coincidencia, [iconoPorDefecto]).
const Map<String, IconData> iconosPorCategoria = {
  'Programación': Icons.code,
  'Diseño': Icons.palette_outlined,
  'Tutorías': Icons.menu_book_outlined,
  'Ensayos y redacción': Icons.edit_outlined,
  'Proyectos': Icons.folder_outlined,
  'Arriendo de habitaciones': Icons.home_outlined,
  'Otros servicios': Icons.public,
};

const IconData iconoPorDefecto = Icons.push_pin_outlined;

/// Colores por categoría, usados en chips y marcadores de imagen.
const Map<String, CategoriaColor> coloresCategoria = {
  'Programación': CategoriaColor(Color(0x1A60A5FA), Color(0xFF60A5FA)),
  'Diseño': CategoriaColor(Color(0x1AF472B6), Color(0xFFF472B6)),
  'Tutorías': CategoriaColor(Color(0x1AA78BFA), Color(0xFFA78BFA)),
  'Ensayos y redacción': CategoriaColor(Color(0x1AFBBF24), Color(0xFFFBBF24)),
  'Proyectos': CategoriaColor(Color(0x1A34D399), Color(0xFF34D399)),
  'Arriendo de habitaciones': CategoriaColor(
    Color(0x1AFB923C),
    Color(0xFFFB923C),
  ),
  'Otros servicios': CategoriaColor(Color(0x1A94A3B8), Color(0xFF94A3B8)),
};

/// Filtros del home en el orden en que se muestran.
const List<ChipCategoria> chipsCategoria = [
  ChipCategoria('Todos', 'todos', Icons.grid_view_rounded),
  ChipCategoria('Tutorías', 'tutorias', Icons.menu_book_outlined, 1),
  ChipCategoria('Ensayos', 'ensayos', Icons.edit_outlined, 2),
  ChipCategoria('Proyectos', 'proyectos', Icons.folder_outlined, 3),
  ChipCategoria('Programación', 'programacion', Icons.code, 4),
  ChipCategoria('Diseño', 'diseno', Icons.palette_outlined, 5),
  ChipCategoria('Arriendo', 'arriendo', Icons.home_outlined, 6),
  ChipCategoria('Otros', 'otros', Icons.public, 7),
];

/// Valores de la API -> texto para mostrar.
const Map<String, String> modalidades = {
  'presencial': 'Presencial',
  'virtual': 'Virtual',
  'mixta': 'Mixta',
};

/// Igual que [modalidades]: valor guardado en la BD -> etiqueta visible.
const Map<String, String> disponibilidades = {
  'entre_semana': 'Entre semana',
  'fines_de_semana': 'Fines de semana',
  'siempre': 'Siempre disponible',
};

/// Sufijo de precio que se concatena en [textoPrecio].
const Map<String, String> unidadesPrecio = {
  'hora': 'por hora',
  'mes': 'por mes',
  'proyecto': 'por proyecto',
};

/// 20000, 'hora' -> "$20.000 / hora".
String textoPrecio(int precio, String unidad) =>
    '${formatearPrecio(precio)} / $unidad';

/// Estado de un servicio propio -> (etiqueta, color).
(String, Color) estadoServicio(String estado) => switch (estado) {
  'aprobado' => ('Publicado', const Color(0xFF34D399)),
  'pausado' => ('Pausado', const Color(0xFF94A3B8)),
  'rechazado' => ('Rechazado', const Color(0xFFFF6B6B)),
  _ => ('En revisión', const Color(0xFFF5C842)),
};

/// Opciones del select de ordenamiento: valor -> etiqueta.
const Map<String, String> opcionesOrden = {
  'recientes': 'Más recientes',
  'antiguos': 'Más antiguos',
  'precio-menor': 'Menor precio',
  'precio-mayor': 'Mayor precio',
  'rating-mayor': 'Mejor calificación',
  'rating-menor': 'Peor calificación',
};

/// Pares usados por el botón de invertir orden.
const Map<String, String> paresOrden = {
  'recientes': 'antiguos',
  'antiguos': 'recientes',
  'precio-menor': 'precio-mayor',
  'precio-mayor': 'precio-menor',
  'rating-mayor': 'rating-menor',
  'rating-menor': 'rating-mayor',
};

/// Quita tildes, pasa a minúsculas y recorta (utilidades.js -> normalizar).
String normalizar(String? texto) {
  const origen = 'áàäâãéèëêíìïîóòöôõúùüûñÁÀÄÂÃÉÈËÊÍÌÏÎÓÒÖÔÕÚÙÜÛÑ';
  const destino = 'aaaaaeeeeiiiiooooouuuunAAAAAEEEEIIIIOOOOOUUUUN';
  var salida = (texto ?? '').toLowerCase().trim();
  for (var i = 0; i < origen.length; i++) {
    salida = salida.replaceAll(
      origen[i].toLowerCase(),
      destino[i].toLowerCase(),
    );
  }
  return salida;
}

/// Trunca un texto y agrega "..." (utilidades.js -> truncar).
String truncar(String? texto, [int max = 90]) {
  if (texto == null || texto.isEmpty) return '';
  return texto.length > max ? '${texto.substring(0, max)}...' : texto;
}

/// Nombre corto para chips y etiquetas ("Arriendo de habitaciones" -> "Arriendo").
String etiquetaCategoria(String categoria) => switch (categoria) {
  'Ensayos y redacción' => 'Ensayos',
  'Arriendo de habitaciones' => 'Arriendo',
  'Otros servicios' => 'Otros',
  '' => 'Servicio',
  _ => categoria,
};

/// 20000 -> "$20.000" (pesos colombianos, sin decimales).
String formatearPrecio(int valor) {
  final digitos = valor.abs().toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digitos.length; i++) {
    if (i > 0 && (digitos.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digitos[i]);
  }
  return '\$$buffer';
}

/// 4.75 -> "4,8" (decimal con coma, como se lee en Colombia).
String formatearDecimal(double valor) =>
    valor.toStringAsFixed(1).replaceAll('.', ',');

/// "12 de octubre de 2026" (helpers.js -> formatearFecha con es-CO).
String formatearFecha(DateTime? f) {
  if (f == null) return '—';
  const meses = [
    'enero',
    'febrero',
    'marzo',
    'abril',
    'mayo',
    'junio',
    'julio',
    'agosto',
    'septiembre',
    'octubre',
    'noviembre',
    'diciembre',
  ];
  return '${f.day} de ${meses[f.month - 1]} de ${f.year}';
}
