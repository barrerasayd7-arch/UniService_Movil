import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../../widgets/section_backgrounds.dart';
import '../../widgets/section_label.dart';

/// Sección #publicar: tarjeta grande que abre el formulario de publicación.
class TarjetaPublicar extends StatelessWidget {
  final VoidCallback onAbrir;
  const TarjetaPublicar({super.key, required this.onAbrir});

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final t = movil ? 28.0 : 38.4;

    return SeccionFondo(
      oscura: true,
      fondo: FondoSeccion.circuito,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SectionLabel(text: 'Nuevo servicio'),
                const SizedBox(height: 14),
                Text(
                  'Publicar servicio',
                  textAlign: TextAlign.center,
                  style: AppText.serif(t, height: 1.2),
                ),
                const SizedBox(height: 10),
                Text(
                  'Comparte tu talento con la comunidad universitaria',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(15, color: AppColors.texto2, height: 1.6),
                ),
                const SizedBox(height: 28),
                _PublicarCard(onTap: onAbrir, compacto: movil),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 32,
                  runSpacing: 10,
                  children: const [
                    _Feature(Icons.image_outlined, 'Hasta 5 fotos'),
                    _Feature(Icons.location_on_outlined, 'Ubicación GPS'),
                    _Feature(Icons.access_time, 'Revisión rápida'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icono;
  final String texto;
  const _Feature(this.icono, this.texto);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 16, color: AppColors.teal),
        const SizedBox(width: 8),
        Text(texto, style: AppText.poppins(13.1, color: AppColors.texto2)),
      ],
    );
  }
}

class _PublicarCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool compacto;
  const _PublicarCard({required this.onTap, required this.compacto});

  @override
  Widget build(BuildContext context) {
    final icono = compacto ? 46.0 : 56.0;

    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          transform: Matrix4.translationValues(0, hover ? -4 : 0, 0),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: hover ? AppColors.teal : AppColors.borde),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.15),
                      blurRadius: 48,
                      offset: const Offset(0, 16),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              // Resplandor + cuadrícula de puntos (solo al pasar el cursor)
              Positioned.fill(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: hover ? 1 : 0,
                  child: Stack(
                    children: [
                      Positioned(
                        top: -150,
                        right: -90,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                AppColors.a(AppColors.teal, 0.08),
                                Colors.transparent,
                              ],
                              stops: const [0, 0.7],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(child: CustomPaint(painter: _PuntosPainter())),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: compacto ? 20 : 32,
                  vertical: compacto ? 20 : 28,
                ),
                child: Row(
                  children: [
                    AnimatedScale(
                      duration: const Duration(milliseconds: 300),
                      scale: hover ? 1.1 : 1,
                      child: AnimatedRotation(
                        duration: const Duration(milliseconds: 300),
                        turns: hover ? 0.25 : 0,
                        child: Container(
                          width: icono,
                          height: icono,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(16),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppColors.teal, AppColors.teal2],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.a(AppColors.teal, 0.3),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.add, size: 26, color: AppColors.bg),
                        ),
                      ),
                    ),
                    SizedBox(width: compacto ? 14 : 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Crear nuevo servicio',
                            style: AppText.poppins(17.6, weight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Define título, categoría, precio y detalles de tu servicio',
                            style: AppText.poppins(13.6, color: AppColors.texto2, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      transform: Matrix4.translationValues(hover ? 4 : 0, 0, 0),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hover
                            ? AppColors.teal
                            : AppColors.a(AppColors.teal, 0.10),
                      ),
                      child: Icon(
                        Icons.arrow_forward,
                        size: 18,
                        color: hover ? AppColors.bg : AppColors.teal,
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

class _PuntosPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = AppColors.a(AppColors.teal, 0.05);
    for (double x = 0; x < size.width; x += 20) {
      for (double y = 0; y < size.height; y += 20) {
        canvas.drawCircle(Offset(x, y), 1, p);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
