// Archivo: footer_invitado.dart
// Responsabilidad: pie del inicio público; los enlaces de cuenta redirigen
//   al login porque el invitado no tiene sesión.
// Se usa desde: home_guest_screen.dart, anclado como "soporte".

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// `footer#soporte` (PiePaginaInvitado.jsx). [onAncla] navega dentro del
/// inicio y [onLogin] cubre cualquier enlace que requiera cuenta.
class FooterInvitado extends StatelessWidget {
  final ValueChanged<String> onAncla;
  final VoidCallback onLogin;
  const FooterInvitado({
    super.key,
    required this.onAncla,
    required this.onLogin,
  });

  // Enlace de texto con hover; mismo tratamiento que en el footer autenticado.
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
              color: hover
                  ? AppColors.of(context).teal
                  : AppColors.of(context).texto2,
            ),
          ),
        ),
      ),
    );
  }

  // Columna del pie: título y enlaces apilados.
  Widget _columna(BuildContext context, String titulo, List<Widget> links) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: AppText.poppins(
            16,
            weight: FontWeight.w700,
            color: AppColors.of(context).texto,
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
    // Por debajo de 768px las columnas se reparten en dos filas.
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
                  color: AppColors.of(context).teal,
                ),
              ),
              TextSpan(
                text: 'Service',
                style: AppText.poppins(
                  20.8,
                  weight: FontWeight.w800,
                  color: AppColors.of(context).amarillo,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'La plataforma de intercambio de servicios entre estudiantes '
          'universitarios de Colombia.',
          style: AppText.poppins(
            13.6,
            color: AppColors.of(context).texto2,
            height: 1.6,
          ),
        ),
      ],
    );

    final plataforma = _columna(context, 'Plataforma', [
      _link('Inicio', () => onAncla('inicio')),
      _link('Buscar servicios', () => onAncla('buscar')),
      _link('Publicar servicio', onLogin),
    ]);
    // Los enlaces de cuenta delegan en onLogin: no hay sesión que mostrar.
    final cuenta = _columna(context, 'Mi cuenta', [
      _link('Mis servicios', onLogin),
      _link('Solicitudes', onLogin),
      _link('Perfil', onLogin),
    ]);
    final categorias = _columna(context, 'Categorías', [
      for (final c in [
        'Tutorías',
        'Ensayos',
        'Programación',
        'Diseño',
        'Arriendo',
      ])
        _link(c, () => onAncla('buscar')),
    ]);
    // Información pública: no requiere iniciar sesión.
    final soporte = _columna(context, 'Soporte', [
      _link('Centro de ayuda', () => Navigator.of(context).pushNamed('/ayuda')),
      _link(
        'Términos de uso',
        () => Navigator.of(context).pushNamed('/terminos'),
      ),
      _link('Privacidad', () => Navigator.of(context).pushNamed('/privacidad')),
      _link('Contacto', () => Navigator.of(context).pushNamed('/contacto')),
    ]);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(0, 40, 0, 20),
      decoration: BoxDecoration(
        color: AppColors.of(context).bg,
        border: Border(top: BorderSide(color: AppColors.of(context).borde)),
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
                Divider(color: AppColors.of(context).borde, height: 1),
                const SizedBox(height: 16),
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  children: [
                    Text(
                      '© 2026 UniService — Hecho por y para estudiantes',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(
                        13,
                        color: AppColors.of(context).texto3,
                      ),
                    ),
                    Icon(
                      Icons.school,
                      size: 15,
                      color: AppColors.of(context).texto3,
                    ),
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
