/// Modelo mínimo de un servicio (lo que usa TarjetaServicio.jsx).
/// Cuando conectes el backend, crea aquí el `fromJson`.
class Servicio {
  final int id;
  final String titulo;
  final String descripcion;
  final String categoria; // nombre_categoria
  final String? universidad;
  final String proveedor;
  final int precioHora;
  final double estrellas; // promedio 0..5
  final int numResenas;
  final DateTime fechaPublicacion;

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
  });
}
