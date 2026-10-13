import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/servicio_detalle.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// Dibuja una imagen del servicio: la red si hay URL, o un marcador de ejemplo.
class ImagenServicioView extends StatelessWidget {
  final ImagenServicio imagen;
  final IconData icono;
  final BoxFit fit;
  final double iconSize;
  const ImagenServicioView({
    super.key,
    required this.imagen,
    required this.icono,
    this.fit = BoxFit.cover,
    this.iconSize = 56,
  });

  static const _tonos = [
    [Color(0xFF0EA5A0), Color(0xFF0A3D5C)],
    [Color(0xFF3B82F6), Color(0xFF1E3A8A)],
    [Color(0xFF8B5CF6), Color(0xFF3B1F7A)],
    [Color(0xFFF97316), Color(0xFF7C2D12)],
  ];

  Widget _marcador() {
    final t = _tonos[imagen.tono % _tonos.length];
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [t[0].withAlpha(160), t[1]],
        ),
      ),
      child: Center(
        child: Icon(icono, size: iconSize, color: Colors.white.withAlpha(200)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (imagen.url == null || imagen.url!.trim().isEmpty) return _marcador();
    return Image.network(
      imagen.url!,
      fit: fit,
      width: double.infinity,
      height: double.infinity,
      errorBuilder: (_, __, ___) => _marcador(),
    );
  }
}

/// `.galeria-principal`: imagen grande + miniaturas.
class GaleriaServicio extends StatefulWidget {
  final List<ImagenServicio> imagenes;
  final IconData icono;
  const GaleriaServicio({super.key, required this.imagenes, required this.icono});

  @override
  State<GaleriaServicio> createState() => _GaleriaServicioState();
}

class _GaleriaServicioState extends State<GaleriaServicio> {
  int _actual = 0;

  void _ampliar() {
    final img = widget.imagenes[_actual];
    showDialog<void>(
      context: context,
      barrierColor: const Color(0xD9000000), // rgba(0,0,0,.85)
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Center(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: MediaQuery.of(ctx).size.width * 0.8,
              height: MediaQuery.of(ctx).size.height * 0.8,
              child: ImagenServicioView(
                imagen: img,
                icono: widget.icono,
                fit: BoxFit.contain,
                iconSize: 96,
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final hayImagenes = widget.imagenes.isNotEmpty;
    final altoGrande = ancho <= 1024 ? 200.0 : 360.0;
    final cols = ancho <= 768 ? 3 : 5;

    return Container(
      clipBehavior: Clip.antiAlias,
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Imagen grande ──
          Container(
            height: hayImagenes ? altoGrande : 160,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bg2, AppColors.bg3],
              ),
            ),
            child: hayImagenes
                ? MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: _ampliar,
                      child: ImagenServicioView(
                        imagen: widget.imagenes[_actual],
                        icono: widget.icono,
                      ),
                    ),
                  )
                : Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_outlined,
                          size: 32,
                          color: AppColors.texto2.withAlpha(102),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'No hay imágenes disponibles',
                          style: AppText.poppins(
                            12,
                            color: AppColors.texto2.withAlpha(128),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),

          // ── Miniaturas ──
          if (hayImagenes)
            Container(
              color: AppColors.bg2,
              padding: const EdgeInsets.all(10),
              child: LayoutBuilder(
                builder: (context, box) {
                  const gap = 6.0;
                  final lado = (box.maxWidth - gap * (cols - 1)) / cols;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < widget.imagenes.length; i++)
                        HoverBuilder(
                          builder: (context, hover) {
                            final activa = _actual == i;
                            return GestureDetector(
                              onTap: () => setState(() => _actual = i),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: lado,
                                height: lado,
                                clipBehavior: Clip.antiAlias,
                                decoration: BoxDecoration(
                                  color: activa
                                      ? AppColors.a(AppColors.teal, 0.15)
                                      : (hover ? AppColors.tealDim : AppColors.card),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: activa || hover
                                        ? AppColors.teal
                                        : AppColors.borde,
                                    width: 2,
                                  ),
                                ),
                                child: ImagenServicioView(
                                  imagen: widget.imagenes[i],
                                  icono: widget.icono,
                                  iconSize: 20,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}
