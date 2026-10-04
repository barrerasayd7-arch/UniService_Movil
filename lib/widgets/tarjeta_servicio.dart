import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/categorias.dart';
import '../models/servicio.dart';
import 'app_buttons.dart' show HoverBuilder;
import 'star_rating.dart';

/// `.card-servicio`: tarjeta de 400x500 con icono, etiqueta, título,
/// descripción, autor, fecha, estrellas y precio.
/// En modo invitado, al tocarla redirige al login (linkBase="/login?id=").
class TarjetaServicio extends StatelessWidget {
  final Servicio servicio;
  final VoidCallback onTap;
  const TarjetaServicio({super.key, required this.servicio, required this.onTap});

  String? get _universidad {
    final u = servicio.universidad;
    if (u == null || u.isEmpty) return null;
    if (u == 'No pertenece a ninguna universidad' || u == 'Sin universidad') return null;
    return u;
  }

  @override
  Widget build(BuildContext context) {
    final colorCat = coloresCategoria[servicio.categoria] ??
        (servicio.categoria.isNotEmpty
            ? const CategoriaColor(Color(0x1A94A3B8), Color(0xFF94A3B8))
            : null);
    final icono = iconosPorCategoria[servicio.categoria] ?? iconoPorDefecto;
    final uni = _universidad;

    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          width: double.infinity,
          height: 500,
          transform: Matrix4.translationValues(0, hover ? -4 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: hover ? AppColors.cardHover : AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: hover ? AppColors.borde2 : AppColors.borde),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(102),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                  ]
                : const [],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // .card-icono (sin foto -> icono sobre degradado teal)
              Container(
                height: 180,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  border: const Border(bottom: BorderSide(color: AppColors.borde)),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.a(AppColors.teal, 0.15),
                      AppColors.a(AppColors.teal, 0.02),
                    ],
                  ),
                ),
                child: Icon(icono, size: 40, color: AppColors.teal),
              ),

              // .card-body-custom
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (colorCat != null)
                        Align(
                          alignment: Alignment.center,
                          child: Container(
                            constraints: const BoxConstraints(minWidth: 120),
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: colorCat.bg,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: colorCat.color.withAlpha(51)),
                            ),
                            child: Text(
                              servicio.categoria.toUpperCase(),
                              textAlign: TextAlign.center,
                              style: AppText.poppins(
                                11.2,
                                weight: FontWeight.w600,
                                color: colorCat.color,
                                spacing: 0.5,
                              ),
                            ),
                          ),
                        ),
                      if (uni != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 4),
                          child: Text(
                            uni,
                            style: AppText.poppins(12, color: AppColors.texto3),
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6, top: 2),
                        child: Text(
                          servicio.titulo.isEmpty ? 'Sin título' : servicio.titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            16,
                            weight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          truncar(servicio.descripcion),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            13.6,
                            color: AppColors.texto2,
                            height: 1.4,
                          ),
                        ),
                      ),
                      // .card-autor
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 32,
                              height: 32,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppColors.a(AppColors.teal, 0.2),
                              ),
                              child: Text(
                                (servicio.proveedor.isEmpty ? '?' : servicio.proveedor[0])
                                    .toUpperCase(),
                                style: AppText.poppins(
                                  12,
                                  weight: FontWeight.w700,
                                  color: const Color(0xFF4AC7B6),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                servicio.proveedor.isEmpty
                                    ? 'Proveedor anónimo'
                                    : servicio.proveedor,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.poppins(13.12, color: AppColors.texto2),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // .texto-fecha
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          formatearFecha(servicio.fechaPublicacion),
                          style: AppText.poppins(13.12, color: AppColors.texto),
                        ),
                      ),
                      // .card-divider
                      Container(
                        height: 1,
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        color: AppColors.borde,
                      ),
                      // .card-footer
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              StarRating(rating: servicio.estrellas, size: 16),
                              const SizedBox(height: 2),
                              Text(
                                '${servicio.numResenas} reseñas',
                                style: AppText.poppins(13.12, color: AppColors.texto2),
                              ),
                            ],
                          ),
                          Text(
                            '\$${servicio.precioHora}',
                            style: AppText.poppins(
                              16,
                              weight: FontWeight.w800,
                              color: AppColors.teal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rejilla `repeat(auto-fill, minmax(360px, 1fr))` con tarjetas de máx. 400px.
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
        const gap = 20.0;
        const minAncho = 360.0;
        final cols = ((box.maxWidth + gap) / (minAncho + gap)).floor().clamp(1, 6).toInt();
        final ancho = ((box.maxWidth - gap * (cols - 1)) / cols).clamp(0.0, 400.0).toDouble();
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final s in servicios)
              SizedBox(
                width: ancho,
                child: TarjetaServicio(servicio: s, onTap: () => onTapServicio(s)),
              ),
          ],
        );
      },
    );
  }
}
