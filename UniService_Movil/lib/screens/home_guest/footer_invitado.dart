import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// `footer#soporte` (PiePaginaInvitado.jsx).
class FooterInvitado extends StatelessWidget {
  final ValueChanged<String> onAncla;
  final VoidCallback onLogin;
  const FooterInvitado({super.key, required this.onAncla, required this.onLogin});

  Widget _link(String texto, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Text(
            texto,
            style: AppText.poppins(
              13.6,
              color: hover ? AppColors.teal : AppColors.texto2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _columna(String titulo, List<Widget> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: AppText.poppins(
            16,
            weight: FontWeight.w700,
            color: const Color(0xFFE8EDF5),
          ),
        ),
        const SizedBox(height: 12),
        ...links,
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final apilado = ancho < 768;

    final marca = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'Uni',
                style: AppText.poppins(
                  20.8,
                  weight: FontWeight.w800,
                  color: AppColors.teal,
                ),
              ),
              TextSpan(
                text: 'Service',
                style: AppText.poppins(
                  20.8,
                  weight: FontWeight.w800,
                  color: AppColors.amarillo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'La plataforma de intercambio de servicios entre estudiantes '
          'universitarios de Colombia.',
          style: AppText.poppins(13.6, color: AppColors.texto2, height: 1.6),
        ),
      ],
    );

    final plataforma = _columna('Plataforma', [
      _link('Inicio', () => onAncla('inicio')),
      _link('Buscar servicios', () => onAncla('buscar')),
      _link('Publicar servicio', onLogin),
    ]);
    final cuenta = _columna('Mi cuenta', [
      _link('Mis servicios', onLogin),
      _link('Solicitudes', onLogin),
      _link('Perfil', onLogin),
    ]);
    final categorias = _columna('Categorías', [
      for (final c in ['Tutorías', 'Ensayos', 'Programación', 'Diseño', 'Arriendo'])
        _link(c, () => onAncla('buscar')),
    ]);
    final soporte = _columna('Soporte', [
      _link('Centro de ayuda', () {}),
      _link('Términos de uso', () {}), 
      _link('Privacidad', () {}), 
      _link('Contacto', () {}),
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 20),
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                if (apilado) ...[
                  Align(alignment: Alignment.centerLeft, child: marca),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: plataforma),
                      Expanded(child: cuenta),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: categorias),
                      Expanded(child: soporte),
                    ],
                  ),
                ] else
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: marca),
                      const SizedBox(width: 24),
                      Expanded(flex: 2, child: plataforma),
                      Expanded(flex: 2, child: cuenta),
                      Expanded(flex: 2, child: categorias),
                      Expanded(flex: 2, child: soporte),
                    ],
                  ),
                const SizedBox(height: 24),
                const Divider(color: AppColors.borde, height: 1),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '© 2026 UniService — Hecho por y para estudiantes',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(13, color: AppColors.texto3),
                    ),
                    const Icon(Icons.school, size: 15, color: AppColors.texto3),
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
