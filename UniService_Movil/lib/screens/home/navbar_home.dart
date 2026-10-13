import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

class EnlaceNavHome {
  final String label;
  final String ancla;
  const EnlaceNavHome(this.label, this.ancla);
}

const enlacesNavHome = [
  EnlaceNavHome('Inicio', 'inicio'),
  EnlaceNavHome('Buscar servicios', 'buscar'),
  EnlaceNavHome('Top destacados', 'mejor-calificados'),
  EnlaceNavHome('Publicar servicio', 'publicar'),
  EnlaceNavHome('Soporte', 'soporte'),
];

enum EstiloNav { normal, solicitudes, perfil, cerrar }

/// Botón de la barra: cambia de colores según su estilo (.nav-link-custom,
/// .nav-solicitudes-btn, .nav-iniciar, .nav-Cerrar).
class NavBoton extends StatelessWidget {
  final String label;
  final EstiloNav estilo;
  final VoidCallback onTap;
  final IconData? icono;
  final bool bloque; // true en el menú móvil (ocupa todo el ancho)

  const NavBoton({
    super.key,
    required this.label,
    required this.onTap,
    this.estilo = EstiloNav.normal,
    this.icono,
    this.bloque = false,
  });

  static const _rojo = Color(0xFFEF4444);
  static const _rojoClaro = Color(0xFFF87171);

  ({Color fg, Color bg, Color borde}) _colores(bool hover) {
    switch (estilo) {
      case EstiloNav.normal:
        return (
          fg: hover ? AppColors.texto : AppColors.texto2,
          bg: hover ? AppColors.tealDim : Colors.transparent,
          borde: Colors.transparent,
        );
      case EstiloNav.solicitudes:
        return (
          fg: hover ? AppColors.bg : AppColors.amarillo,
          bg: hover ? AppColors.amarillo : AppColors.a(AppColors.amarillo, 0.10),
          borde: hover ? AppColors.amarillo : AppColors.a(AppColors.amarillo, 0.25),
        );
      case EstiloNav.perfil:
        return (
          fg: hover ? AppColors.bg : AppColors.teal,
          bg: hover ? AppColors.teal : AppColors.a(AppColors.teal, 0.15),
          borde: hover ? AppColors.teal : AppColors.a(AppColors.teal, 0.35),
        );
      case EstiloNav.cerrar:
        return (
          fg: hover ? Colors.white : _rojoClaro,
          bg: hover ? _rojo : AppColors.a(_rojo, 0.15),
          borde: hover ? _rojo : AppColors.a(_rojo, 0.35),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final destacado = estilo != EstiloNav.normal;
    Widget texto(Color fg) => Text(
          label,
          overflow: TextOverflow.ellipsis,
          style: AppText.poppins(
            13.12,
            weight: destacado ? FontWeight.w600 : FontWeight.w500,
            color: fg,
          ),
        );
    return HoverBuilder(
      builder: (context, hover) {
        final c = _colores(hover);
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: bloque ? double.infinity : null,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: c.bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: c.borde),
            ),
            child: Row(
              mainAxisSize: bloque ? MainAxisSize.max : MainAxisSize.min,
              children: [
                if (icono != null) ...[
                  Icon(icono, size: 16, color: c.fg),
                  const SizedBox(width: 5),
                ],
                // Flexible solo cuando hay ancho acotado (menú móvil); en la
                // barra de escritorio el ancho es ilimitado y fallaría.
                if (bloque)
                  Flexible(child: texto(c.fg))
                else
                  texto(c.fg),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// `.navbar-custom` para usuarios autenticados (BarraNavegacion.jsx).
class NavbarHome extends StatelessWidget {
  final bool movil;
  final bool menuAbierto;
  final bool scrolled;
  final String nombreUsuario;
  final VoidCallback onToggleMenu;
  final ValueChanged<String> onAncla;
  final VoidCallback onSolicitudes;
  final VoidCallback onPerfil;
  final VoidCallback onCerrarSesion;

  const NavbarHome({
    super.key,
    required this.movil,
    required this.menuAbierto,
    required this.scrolled,
    required this.nombreUsuario,
    required this.onToggleMenu,
    required this.onAncla,
    required this.onSolicitudes,
    required this.onPerfil,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xF2070D16),
            border: const Border(bottom: BorderSide(color: AppColors.borde)),
            boxShadow: scrolled
                ? [
                    BoxShadow(
                      color: Colors.black.withAlpha(90),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTap: () => onAncla('inicio'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Uni',
                                style: AppText.poppins(
                                  24,
                                  weight: FontWeight.w700,
                                  color: AppColors.teal,
                                  spacing: 0.5,
                                ),
                              ),
                              TextSpan(
                                text: 'Service',
                                style: AppText.poppins(
                                  24,
                                  weight: FontWeight.w700,
                                  color: AppColors.amarillo,
                                  spacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (movil)
                      _Hamburguesa(activo: menuAbierto, onTap: onToggleMenu)
                    else
                      Flexible(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            for (final e in enlacesNavHome)
                              Padding(
                                padding: const EdgeInsets.only(left: 2),
                                child: NavBoton(
                                  label: e.label,
                                  onTap: () => onAncla(e.ancla),
                                ),
                              ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: NavBoton(
                                label: 'Mis solicitudes',
                                estilo: EstiloNav.solicitudes,
                                onTap: onSolicitudes,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: NavBoton(
                                label: nombreUsuario,
                                icono: Icons.person_outline,
                                estilo: EstiloNav.perfil,
                                onTap: onPerfil,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: NavBoton(
                                label: 'Cerrar Sesión',
                                estilo: EstiloNav.cerrar,
                                onTap: onCerrarSesion,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Hamburguesa extends StatelessWidget {
  final bool activo;
  final VoidCallback onTap;
  const _Hamburguesa({required this.activo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    Widget barra({double giro = 0, double dy = 0, double opacidad = 1}) {
      return AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 25,
        height: 2,
        transformAlignment: Alignment.center,
        transform: Matrix4.translationValues(0, dy, 0)..rotateZ(giro),
        color: AppColors.texto.withAlpha((opacidad * 255).round()),
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(5),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            barra(giro: activo ? 0.785398 : 0, dy: activo ? 7 : 0),
            const SizedBox(height: 5),
            barra(opacidad: activo ? 0 : 1),
            const SizedBox(height: 5),
            barra(giro: activo ? -0.785398 : 0, dy: activo ? -7 : 0),
          ],
        ),
      ),
    );
  }
}

/// Menú desplegable en pantallas pequeñas.
class MenuMovilHome extends StatelessWidget {
  final String nombreUsuario;
  final ValueChanged<String> onAncla;
  final VoidCallback onSolicitudes;
  final VoidCallback onPerfil;
  final VoidCallback onCerrarSesion;

  const MenuMovilHome({
    super.key,
    required this.nombreUsuario,
    required this.onAncla,
    required this.onSolicitudes,
    required this.onPerfil,
    required this.onCerrarSesion,
  });

  @override
  Widget build(BuildContext context) {
    Widget fila(Widget w) =>
        Padding(padding: const EdgeInsets.symmetric(vertical: 2.5), child: w);

    return Container(
      constraints: const BoxConstraints(minWidth: 200, maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final e in enlacesNavHome)
              fila(NavBoton(label: e.label, bloque: true, onTap: () => onAncla(e.ancla))),
            fila(NavBoton(
              label: 'Mis solicitudes',
              bloque: true,
              estilo: EstiloNav.solicitudes,
              onTap: onSolicitudes,
            )),
            fila(NavBoton(
              label: nombreUsuario,
              bloque: true,
              icono: Icons.person_outline,
              estilo: EstiloNav.perfil,
              onTap: onPerfil,
            )),
            fila(NavBoton(
              label: 'Cerrar Sesión',
              bloque: true,
              estilo: EstiloNav.cerrar,
              onTap: onCerrarSesion,
            )),
          ],
        ),
      ),
    );
  }
}
