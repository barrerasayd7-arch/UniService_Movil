/// Servicio tal como lo muestran las tarjetas del inicio.
/// Los campos siguen el listado de la API (`uniservice_mobile.listar_servicios`).
/// Cuando conectes el backend, crea aquí el `fromJson`.
class Servicio {
  final int id;
  final String titulo;
  final String descripcion;
  final String categoria; // nombre_categoria
  final String? universidad;
  final String proveedor;
  final int precioHora; // precio en COP por [unidadPrecio]
  final String unidadPrecio; // 'hora' | 'mes' | 'proyecto'
  final double estrellas; // promedio 0..5
  final int numResenas;
  final DateTime fechaPublicacion;
  final String? imagenUrl; // portada (orden 0); null = sin fotos
  final String? avatarProveedor;

  const Servicio({
    required this.id,
    required this.titulo,
    required this.descripcion,
    required this.categoria,
    required this.proveedor,
    required this.precioHora,
    required this.estrellas,
    required this.numResenas,
    required this.fechaPublicacion,
    this.universidad,
    this.unidadPrecio = 'hora',
    this.imagenUrl,
    this.avatarProveedor,
  });
}
