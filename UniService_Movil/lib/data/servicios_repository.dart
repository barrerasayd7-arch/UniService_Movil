import 'package:flutter/foundation.dart';

import '../models/mi_servicio.dart';
import '../models/servicio.dart';
import '../models/servicio_detalle.dart';
import 'api_client.dart';
import 'auth_repository.dart';

/// Lo que escribe el proveedor al publicar o editar (cuerpo de POST/PUT /api/servicios).
class DatosServicio {
  final String titulo;
  final String descripcion;
  final int idCategoria;
  final int precio;
  final String unidadPrecio; // hora | mes | proyecto
  final String modalidad; // presencial | virtual | mixta
  final String disponibilidad; // entre_semana | fines_de_semana | siempre
  final String contacto;
  final String? direccion;

  const DatosServicio({
    required this.titulo,
    required this.descripcion,
    required this.idCategoria,
    required this.precio,
    required this.unidadPrecio,
    required this.modalidad,
    required this.disponibilidad,
    required this.contacto,
    this.direccion,
  });

  Map<String, dynamic> toJson() => {
    'titulo': titulo.trim(),
    'descripcion': descripcion.trim(),
    'id_categoria': idCategoria,
    'precio': precio,
    'unidad_precio': unidadPrecio,
    'modalidad': modalidad,
    'disponibilidad': disponibilidad,
    'contacto': contacto.trim(),
    'direccion': (direccion?.trim().isEmpty ?? true) ? null : direccion!.trim(),
  };
}

/// Servicios: listado público, detalle y gestión de los propios (`/api/servicios`).
class ServiciosRepository {
  ServiciosRepository([ApiClient? api])
    : _api = api ?? AuthRepository.instance.api;

  static final ServiciosRepository instance = ServiciosRepository();

  final ApiClient _api;

  /// Aumenta cada vez que el usuario publica, edita, pausa o borra un servicio,
  /// para que las listas abiertas se recarguen.
  final ValueNotifier<int> cambios = ValueNotifier(0);

  void _avisarCambio() => cambios.value++;

  Future<PaginaServicios> listar({
    int pagina = 1,
    int porPagina = 12,
    int? categoria,
    String? busqueda,
    String orden = 'recientes',
  }) async {
    final query = Uri(
      queryParameters: {
        'pagina': '$pagina',
        'por_pagina': '$porPagina',
        'orden': orden,
        if (categoria != null) 'categoria': '$categoria',
        if (busqueda != null && busqueda.trim().isNotEmpty)
          'busqueda': busqueda.trim(),
      },
    ).query;
    final data = await _api.get('/api/servicios?$query');
    return PaginaServicios.fromJson(data as Map<String, dynamic>);
  }

  Future<ServicioDetalle> detalle(int id) async {
    final data = await _api.get('/api/servicios/$id');
    return ServicioDetalle.fromJson(data as Map<String, dynamic>);
  }

  Future<List<MiServicio>> mios() async {
    final data = await _api.get('/api/servicios/mios') as List;
    return [for (final s in data) MiServicio.fromJson(s as Map<String, dynamic>)];
  }

  /// Publica y devuelve el id del servicio (queda `pendiente` de revisión).
  Future<int> crear(DatosServicio datos) async {
    final data = await _api.post('/api/servicios', datos.toJson()) as Map;
    _avisarCambio();
    return leerInt(data['id_servicio']);
  }

  /// Guarda los cambios; el servicio vuelve a `pendiente`.
  Future<void> editar(int id, DatosServicio datos) async {
    await _api.put('/api/servicios/$id', datos.toJson());
    _avisarCambio();
  }

  /// Pausa (aprobado → pausado) o reanuda (pausado → aprobado). Devuelve el estado nuevo.
  Future<String> pausar(int id, {required bool pausado}) async {
    final data = await _api.patch('/api/servicios/$id/pausa', {
      'pausado': pausado,
    });
    _avisarCambio();
    return (data is Map ? data['estado'] as String? : null) ??
        (pausado ? 'pausado' : 'aprobado');
  }

  Future<void> eliminar(int id) async {
    await _api.delete('/api/servicios/$id');
    _avisarCambio();
  }

  /// Sube de 1 a 5 fotos (JPG, PNG o WebP de hasta 5 MB). El servicio vuelve a `pendiente`.
  Future<void> subirImagenes(int id, List<ArchivoSubida> imagenes) async {
    await _api.subirArchivos('/api/servicios/$id/imagenes', 'imagenes', imagenes);
    _avisarCambio();
  }

  /// [ids] son todas las imágenes del servicio en el orden nuevo; la primera es la portada.
  Future<void> ordenarImagenes(int id, List<int> ids) async {
    await _api.put('/api/servicios/$id/imagenes/orden', {'imagenes': ids});
    _avisarCambio();
  }

  Future<void> eliminarImagen(int id, int idImagen) async {
    await _api.delete('/api/servicios/$id/imagenes/$idImagen');
    _avisarCambio();
  }
}
