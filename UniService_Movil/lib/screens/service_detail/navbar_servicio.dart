import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../home/navbar_home.dart' show NavBoton, EstiloNav;

/// Barra de BarraNavegacionServicio.jsx:
/// Inicio · Servicios · Publicar servicio · Perfil · Cerrar Sesión.
class NavbarServicio extends StatelessWidget {
  final bool movil;
  final bool menuAbierto;
  final VoidCallback onToggleMenu;
  final ValueChanged<String> onEnlace; // inicio | buscar | publicar | perfil
  final VoidCallback onCerrarSesion;

  const NavbarServicio({
    super.key,
    required this.movil,
    required this.menuAbierto,
    required this.onToggleMenu,
    required this.onEnlace,
    required this.onCerrarSesion,
  });

  static const enlaces = [
    ('Inicio', 'inicio'),
    ('Servicios', 'buscar'),
    ('Publicar servicio', 'publicar'),
    ('Perfil', 'perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: const BoxDecoration(
            color: Color(0xF2070D16),
            border: Border(bottom: BorderSide(color: AppColors.borde)),
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
                      onTap: () => onEnlace('inicio'),
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: 'Uni',
                                style: AppText.poppins(24,
                                    weight: FontWeight.w700,
                                    color: AppColors.teal,
                                    spacing: 0.5),
                              ),
                              TextSpan(
                                text: 'Service',
                                style: AppText.poppins(24,
                                    weight: FontWeight.w700,
                                    color: AppColors.amarillo,
                                    spacing: 0.5),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (movil)
                      GestureDetector(
                        onTap: onToggleMenu,
                        child: Padding(
                          padding: const EdgeInsets.all(5),
                          child: Icon(
                            menuAbierto ? Icons.close : Icons.menu,
                            color: AppColors.texto,
                            size: 28,
                          ),
                        ),
                      )
                    else
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final e in enlaces)
                            Padding(
                              padding: const EdgeInsets.only(left: 2),
                              child: NavBoton(label: e.$1, onTap: () => onEnlace(e.$2)),
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

/// Menú desplegable para pantallas pequeñas.
class MenuMovilServicio extends StatelessWidget {
  final ValueChanged<String> onEnlace;
  final VoidCallback onCerrarSesion;
  const MenuMovilServicio({super.key, required this.onEnlace, required this.onCerrarSesion});

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
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final e in NavbarServicio.enlaces)
              fila(NavBoton(label: e.$1, bloque: true, onTap: () => onEnlace(e.$2))),
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
