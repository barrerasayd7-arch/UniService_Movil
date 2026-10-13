import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart';
import '../../widgets/floating_icons.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tesseract_background.dart';

/// `.hero` (Presentacion.jsx): fondo con tesseract 4D, iconos flotantes,
/// título, descripción y dos botones.
class HeroPresentacion extends StatelessWidget {
  final VoidCallback onExplorar;
  final VoidCallback onPublicar;
  const HeroPresentacion({super.key, required this.onExplorar, required this.onPublicar});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final movil = size.width <= Breakpoints.mobile;
    final h1 = movil ? 32.0 : 57.6;

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height * (movil ? 0.7 : 1.0)),
      child: Stack(
        children: [
          const Positioned.fill(child: ColoredBox(color: AppColors.bg)),
          const Positioned.fill(child: TesseractBackground()),
          const Positioned.fill(child: FloatingIcons()),
          // Gradiente oscuro encima para que resalten las letras
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.6, 1],
                    colors: [
                      AppColors.a(AppColors.bg, 0),
                      AppColors.a(AppColors.bg, 0.3),
                      AppColors.a(AppColors.bg, 0.8),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              left: movil ? 24 : size.width * 0.055,
              right: 24,
              top: movil ? 40 : 100,
              bottom: movil ? 40 : 80,
            ),
            child: Align(
              alignment: movil ? Alignment.topLeft : Alignment.centerLeft,
              child: Transform.translate(
                offset: Offset(0, movil ? 0 : -size.height * 0.088),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!movil) ...[
                      const SectionLabel(text: 'Plataforma Universitaria'),
                      const SizedBox(height: 10),
                    ],
                    if (movil) const SizedBox(height: 264),
                    Text.rich(
                      TextSpan(
                        style: AppText.serif(
                          h1,
                          height: 1.15,
                          shadows: movil
                              ? null
                              : [Shadow(color: AppColors.a(AppColors.teal, 0.08), blurRadius: 60)],
                        ),
                        children: [
                          const TextSpan(text: 'Intercambia '),
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: AcentoText('servicios', fontSize: h1),
                          ),
                          const TextSpan(text: '\nentre estudiantes universitarios'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (!movil) ...[
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: Text(
                          'Tutorías, ensayos, proyectos, diseño, programación y arriendo de '
                          'habitaciones — todo para la comunidad universitaria en Colombia.',
                          style: AppText.poppins(16, color: AppColors.texto2, height: 1.7),
                        ),
                      ),
                      const SizedBox(height: 36),
                    ] else
                      const SizedBox(height: 10),
                    if (movil)
                      SizedBox(
                        width: size.width * 0.7,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            BtnVerde(label: 'Explorar servicios', onTap: onExplorar),
                            const SizedBox(height: 12),
                            BtnBorde(label: 'Publicar mi servicio', onTap: onPublicar),
                          ],
                        ),
                      )
                    else
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          BtnVerde(label: 'Explorar servicios', onTap: onExplorar),
                          BtnBorde(label: 'Publicar mi servicio', onTap: onPublicar),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
