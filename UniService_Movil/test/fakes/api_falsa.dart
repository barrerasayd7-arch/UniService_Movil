import 'dart:convert';

import 'package:app_uniservice/data/api_client.dart';
import 'package:app_uniservice/data/servicios_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Fila de `GET /api/servicios` como la devuelve el backend (precio decimal incluido).
Map<String, dynamic> filaServicio(
  int id,
  String titulo, {
  int categoria = 1,
  String nombreCategoria = 'Tutorías',
  num precio = 20000.00,
  int resenas = 0,
  double promedio = 0,
  String? imagen,
}) => {
  'id_servicio': id,
  'id_proveedor': 100 + id,
  'titulo': titulo,
  'descripcion': 'Descripción del servicio $titulo con suficiente detalle.',
  'id_categoria': categoria,
  'categoria': nombreCategoria,
  'precio': precio,
  'unidad_precio': categoria == 6 ? 'mes' : 'hora',
  'modalidad': 'presencial',
  'disponibilidad': 'siempre',
  'fecha_publicacion': '2026-09-${(id % 28 + 1).toString().padLeft(2, '0')}T12:00:00Z',
  'proveedor': 'Proveedor $id',
  'universidad': 'Universidad Popular del Cesar',
  'avatar': null,
  'imagen': imagen,
  'num_resenas': resenas,
  'promedio': promedio,
};

/// Catálogo de ejemplo: 15 servicios (más de una página de 12).
final List<Map<String, dynamic>> catalogo = [
  filaServicio(1, 'Tutoría de Cálculo Diferencial', resenas: 24, promedio: 4.8),
  filaServicio(2, 'Redacción de ensayos', categoria: 2, nombreCategoria: 'Ensayos y redacción', resenas: 3, promedio: 4.5),
  filaServicio(3, 'Desarrollo de apps con Flutter', categoria: 4, nombreCategoria: 'Programación', resenas: 31, promedio: 5),
  filaServicio(4, 'Diseño de logos', categoria: 5, nombreCategoria: 'Diseño'),
  filaServicio(5, 'Habitación amoblada', categoria: 6, nombreCategoria: 'Arriendo de habitaciones', precio: 450000.00, resenas: 2, promedio: 4),
  for (var i = 6; i <= 15; i++) filaServicio(i, 'Tutoría de repaso $i'),
];

/// API falsa de servicios: filtra por categoría y búsqueda, ordena por calificación y pagina.
/// Guarda las peticiones en [peticiones]. Con [fallar] responde 500.
class ApiFalsa {
  final List<Uri> peticiones = [];
  bool fallar = false;
  final List<Map<String, dynamic>> datos;

  ApiFalsa([List<Map<String, dynamic>>? datos]) : datos = datos ?? catalogo;

  ServiciosRepository repositorio() => ServiciosRepository(
    ApiClient(client: MockClient(_responder), baseUrl: 'http://api.test'),
  );

  Future<http.Response> _responder(http.Request r) async {
    peticiones.add(r.url);
    if (fallar) {
      return _json({'error': 'Error interno del servidor'}, 500);
    }
    if (r.url.path != '/api/servicios') return _json({'error': 'No existe'}, 404);
    final q = r.url.queryParameters;
    final pagina = int.parse(q['pagina'] ?? '1');
    final porPagina = int.parse(q['por_pagina'] ?? '12');
    final categoria = int.tryParse(q['categoria'] ?? '');
    final busqueda = (q['busqueda'] ?? '').toLowerCase();
    var lista = datos
        .where((s) => categoria == null || s['id_categoria'] == categoria)
        .where(
          (s) =>
              busqueda.isEmpty ||
              (s['titulo'] as String).toLowerCase().contains(busqueda),
        )
        .toList();
    if (q['orden'] == 'rating-mayor') {
      lista.sort(
        (a, b) => (b['promedio'] as num).compareTo(a['promedio'] as num),
      );
    }
    final total = lista.length;
    lista = lista.skip((pagina - 1) * porPagina).take(porPagina).toList();
    return _json({
      'servicios': lista,
      'pagina': pagina,
      'por_pagina': porPagina,
      'total': total,
      'total_paginas': (total / porPagina).ceil(),
    });
  }
}

http.Response _json(Object cuerpo, [int status = 200]) => http.Response(
  jsonEncode(cuerpo),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

/// Detalle como lo devuelve `GET /api/servicios/{id}` a un invitado.
Map<String, dynamic> detalleInvitado() => {
  'servicio': {
    'id_servicio': 69,
    'titulo': 'Pensión cerca de la UPC',
    'descripcion': 'Habitación con aire acondicionado y derecho a cocina.',
    'id_categoria': 6,
    'categoria': 'Arriendo de habitaciones',
    'precio': 450000.00,
    'unidad_precio': 'mes',
    'modalidad': 'presencial',
    'disponibilidad': 'siempre',
    'fecha_publicacion': '2026-05-28T00:11:37.375646Z',
    'estado': 'aprobado',
    'motivo_rechazo': null,
    'es_propio': false,
    'contacto': null,
    'direccion': null,
    'ubicacion_lat': null,
    'ubicacion_lng': null,
    'tiene_ubicacion': true,
    'proveedor': {
      'id_usuario': 2,
      'nombre': 'Said',
      'universidad': 'Universidad Popular del Cesar',
      'avatar': null,
      'servicios_publicados': 1,
      'num_resenas': 3,
      'promedio': 4.67,
    },
  },
  'imagenes': [
    {'id_imagen': 131, 'url': 'https://ejemplo.test/69/1.jpg', 'orden': 0},
  ],
  'resenas': [
    {
      'id_calificacion': 12,
      'id_cliente': 3,
      'autor': 'Camilo',
      'avatar': null,
      'puntuacion': 4,
      'comentario': 'Muy buena',
      'fecha': '2026-09-02T04:48:20.89558Z',
      'editada': true,
    },
  ],
  'num_resenas': 3,
  'promedio': 4.67,
};
