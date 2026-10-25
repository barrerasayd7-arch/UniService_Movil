// Archivo: tarjeta_servicio.dart
// Responsabilidad: tarjeta de servicio (portada, categoría, precio, autor y calificación) y la rejilla adaptable.
// Se usa desde: explorador de servicios y otras listas o carruseles de servicios.

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/categorias.dart';
import '../models/servicio.dart';

/// Tarjeta de servicio: portada 16:9 (categoría y precio encima), título,
/// descripción, quién lo ofrece y calificación.
///
/// Con [alturaUniforme] (carruseles y rejillas de varias columnas), título y
/// descripción reservan 2 líneas para que las tarjetas lado a lado midan lo mismo.
/// En una lista de una columna cada tarjeta toma su altura natural.
class TarjetaServicio extends StatelessWidget {
  final Servicio servicio;
  final VoidCallback onTap;
  final bool alturaUniforme;
  const TarjetaServicio({
    super.key,
    required this.servicio,
    required this.onTap,
    this.alturaUniforme = false,
  });

  // Medidas del cuerpo (las alturas de texto escalan con el tamaño de letra del sistema).
  static const double _pad = 14;
  static const double _titulo = 16;
  static const double _tituloAlto = 1.3;
  static const double _desc = 13.5;
  static const double _descAlto = 1.45;
  static const double _autor = 28;

  static double _altoTitulo(TextScaler ts) =>
      ts.scale(_titulo) * _tituloAlto * 2;
  static double _altoDesc(TextScaler ts) => ts.scale(_desc) * _descAlto * 2;

  /// Alto total de una tarjeta de [ancho] (para carruseles con altura fija).
  static double altoPara(double ancho, TextScaler ts) =>
      ancho * 9 / 16 +
      _pad +
      _altoTitulo(ts) +
      6 +
      _altoDesc(ts) +
      12 +
      _autor +
      _pad +
      2;

  @override
  Widget build(BuildContext context) {
    final ts = MediaQuery.textScalerOf(context);
    final s = servicio;
    final calificacion = s.numResenas == 0
        ? 'sin reseñas'
        : '${formatearDecimal(s.estrellas)} estrellas, ${s.numResenas} reseñas';

    return Semantics(
      button: true,
      label:
          '${s.titulo}. ${etiquetaCategoria(s.categoria)}. Por ${s.proveedor}. '
          '$calificacion. ${formatearPrecio(s.precio)} por ${s.unidadPrecio}.',
      excludeSemantics: true,
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.borde),
        ),
        child: InkWell(
          onTap: onTap,
          splashColor: AppColors.a(AppColors.teal, 0.12),
          highlightColor: AppColors.a(AppColors.teal, 0.06),
          hoverColor: AppColors.a(AppColors.texto, 0.03),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _Portada(servicio: s),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: _EtiquetaCategoria(categoria: s.categoria),
                    ),
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: _Precio(
                        valor: s.precio,
                        unidad: s.unidadPrecio,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(_pad),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: alturaUniforme ? _altoTitulo(ts) : null,
                      child: Text(
                        s.titulo.isEmpty ? 'Sin título' : s.titulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          _titulo,
                          weight: FontWeight.w600,
                          height: _tituloAlto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: alturaUniforme ? _altoDesc(ts) : null,
                      child: Text(
                        s.descripcion,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          _desc,
                          color: AppColors.texto2,
                          height: _descAlto,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: _autor,
                      child: Row(
                        children: [
                          _Avatar(nombre: s.proveedor, url: s.avatarProveedor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.proveedor.isEmpty ? 'Estudiante' : s.proveedor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(
                                13,
                                weight: FontWeight.w500,
                                color: AppColors.texto,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _Calificacion(
                            promedio: s.estrellas,
                            resenas: s.numResenas,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto de portada; sin foto (o si no carga) muestra el ícono y el color de la categoría.
class _Portada extends StatelessWidget {
  final Servicio servicio;
  const _Portada({required this.servicio});

  @override
  Widget build(BuildContext context) {
    final respaldo = _PortadaCategoria(categoria: servicio.categoria);
    final url = servicio.imagenUrl;
    if (url == null || url.isEmpty) return respaldo;

    return LayoutBuilder(
      builder: (context, box) {
        // Decodifica la imagen al tamaño en pantalla (no a su resolución original).
        final ancho = (box.maxWidth * MediaQuery.devicePixelRatioOf(context))
            .round();
        return Stack(
          fit: StackFit.expand,
          children: [
            respaldo,
            Image.network(
              url,
              fit: BoxFit.cover,
              cacheWidth: ancho > 0 ? ancho : null,
              errorBuilder: (_, _, _) => const SizedBox.shrink(),
              frameBuilder: (context, child, frame, sincrono) => sincrono
                  ? child
                  : AnimatedOpacity(
                      opacity: frame == null ? 0 : 1,
                      duration: const Duration(milliseconds: 220),
                      child: child,
                    ),
            ),
            // Oscurece el borde inferior para que el precio se lea sobre cualquier foto.
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.center,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x00070D16), Color(0x99070D16)],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Fondo de la portada cuando no hay foto: degradado e ícono propios de la categoría.
class _PortadaCategoria extends StatelessWidget {
  final String categoria;
  const _PortadaCategoria({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final color = coloresCategoria[categoria]?.color ?? AppColors.teal;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.a(color, 0.22), AppColors.bg3],
        ),
      ),
      child: Center(
        child: Icon(
          iconosPorCategoria[categoria] ?? iconoPorDefecto,
          size: 40,
          color: AppColors.a(color, 0.85),
        ),
      ),
    );
  }
}

// Chip sobre la portada con el punto de color y el nombre de la categoría.
class _EtiquetaCategoria extends StatelessWidget {
  final String categoria;
  const _EtiquetaCategoria({required this.categoria});

  @override
  Widget build(BuildContext context) {
    final color = coloresCategoria[categoria]?.color ?? AppColors.texto2;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xD9070D16),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            etiquetaCategoria(categoria),
            style: AppText.poppins(12, weight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// Precio y unidad sobre la esquina inferior de la portada.
class _Precio extends StatelessWidget {
  final int valor;
  final String unidad;
  const _Precio({required this.valor, required this.unidad});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xE6070D16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: formatearPrecio(valor),
              style: AppText.poppins(14, weight: FontWeight.w700),
            ),
            TextSpan(
              text: ' /$unidad',
              style: AppText.poppins(12, color: AppColors.texto2),
            ),
          ],
        ),
      ),
    );
  }
}

// Avatar del proveedor: foto si existe; si no, iniciales calculadas del nombre.
class _Avatar extends StatelessWidget {
  final String nombre;
  final String? url;
  const _Avatar({required this.nombre, this.url});

  String get _iniciales {
    final partes = nombre
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (partes.isEmpty) return '?';
    return (partes.first[0] + (partes.length > 1 ? partes[1][0] : ''))
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final iniciales = Text(
      _iniciales,
      style: AppText.poppins(
        11,
        weight: FontWeight.w700,
        color: AppColors.teal2,
      ),
    );
    return Container(
      width: 28,
      height: 28,
      clipBehavior: Clip.antiAlias,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.a(AppColors.teal, 0.18),
      ),
      child: url == null || url!.isEmpty
          ? iniciales
          : Image.network(
              url!,
              width: 28,
              height: 28,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => iniciales,
            ),
    );
  }
}

// Estrella con promedio y número de reseñas; sin reseñas muestra "Nuevo".
class _Calificacion extends StatelessWidget {
  final double promedio;
  final int resenas;
  const _Calificacion({required this.promedio, required this.resenas});

  @override
  Widget build(BuildContext context) {
    if (resenas == 0) {
      return Text(
        'Nuevo',
        style: AppText.poppins(
          12.5,
          weight: FontWeight.w600,
          color: AppColors.teal2,
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.star_rounded, size: 17, color: AppColors.estrella),
        const SizedBox(width: 3),
        Text(
          formatearDecimal(promedio),
          style: AppText.poppins(13, weight: FontWeight.w600),
        ),
        const SizedBox(width: 3),
        Text(
          '($resenas)',
          style: AppText.poppins(12.5, color: AppColors.texto2),
        ),
      ],
    );
  }
}

/// Rejilla adaptable: 1 columna en celular, hasta 4 en pantallas anchas.
class RejillaServicios extends StatelessWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;
  const RejillaServicios({
    super.key,
    required this.servicios,
    required this.onTapServicio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const gap = 16.0;
        const minAncho = 300.0;
        final cols = ((box.maxWidth + gap) / (minAncho + gap)).floor().clamp(
          1,
          4,
        );
        final ancho = (box.maxWidth - gap * (cols - 1)) / cols;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in servicios)
              SizedBox(
                width: ancho,
                child: TarjetaServicio(
                  servicio: s,
                  onTap: () => onTapServicio(s),
                  alturaUniforme: cols > 1,
                ),
              ),
          ],
        );
      },
    );
  }
}
