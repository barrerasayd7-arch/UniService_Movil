import 'package:flutter/material.dart';

/// Equivalente a shared/constantes.js (iconos, colores y chips de categoría).
/// Los iconos de Bootstrap Icons se reemplazan por Material Icons.
class CategoriaColor {
  final Color bg;
  final Color color;
  const CategoriaColor(this.bg, this.color);
}

class ChipCategoria {
  final String label;
  final String valor;
  final IconData icono;
  const ChipCategoria(this.label, this.valor, this.icono);
}

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

const Map<String, CategoriaColor> coloresCategoria = {
  'Programación': CategoriaColor(Color(0x1A60A5FA), Color(0xFF60A5FA)),
  'Diseño': CategoriaColor(Color(0x1AF472B6), Color(0xFFF472B6)),
  'Tutorías': CategoriaColor(Color(0x1AA78BFA), Color(0xFFA78BFA)),
  'Ensayos y redacción': CategoriaColor(Color(0x1AFBBF24), Color(0xFFFBBF24)),
  'Proyectos': CategoriaColor(Color(0x1A34D399), Color(0xFF34D399)),
  'Arriendo de habitaciones':
      CategoriaColor(Color(0x1AFB923C), Color(0xFFFB923C)),
  'Otros servicios': CategoriaColor(Color(0x1A94A3B8), Color(0xFF94A3B8)),
};

const List<ChipCategoria> chipsCategoria = [
  ChipCategoria('Todos', 'todos', Icons.grid_view_rounded),
  ChipCategoria('Tutorías', 'tutorias', Icons.menu_book_outlined),
  ChipCategoria('Ensayos', 'ensayos', Icons.edit_outlined),
  ChipCategoria('Proyectos', 'proyectos', Icons.folder_outlined),
  ChipCategoria('Programación', 'programacion', Icons.code),
  ChipCategoria('Diseño', 'diseno', Icons.palette_outlined),
  ChipCategoria('Arriendo', 'arriendo', Icons.home_outlined),
];

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
    salida = salida.replaceAll(origen[i].toLowerCase(), destino[i].toLowerCase());
  }
  return salida;
}

/// Trunca un texto y agrega "..." (utilidades.js -> truncar).
String truncar(String? texto, [int max = 90]) {
  if (texto == null || texto.isEmpty) return '';
  return texto.length > max ? '${texto.substring(0, max)}...' : texto;
}

/// "12 de octubre de 2026" (helpers.js -> formatearFecha con es-CO).
String formatearFecha(DateTime? f) {
  if (f == null) return '—';
  const meses = [
    'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
    'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
  ];
  return '${f.day} de ${meses[f.month - 1]} de ${f.year}';
}
