import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

class EnlaceNav {
  final String label;
  final String ancla; // inicio | buscar | mejor-calificados | soporte
  const EnlaceNav(this.label, this.ancla);
}

const enlacesNav = [
  EnlaceNav('Inicio', 'inicio'),
  EnlaceNav('Buscar servicios', 'buscar'),
  EnlaceNav('Top destacados', 'mejor-calificados'),
  EnlaceNav('Soporte', 'soporte'),
];

/// `.navbar-custom` (BarraNavegacionInvitado.jsx).
/// En pantallas < 768px muestra el botón hamburguesa; el menú desplegable
/// lo dibuja [MenuMovilInvitado] desde la pantalla principal.
class NavbarInvitado extends StatelessWidget {
  final bool movil;
  final bool menuAbierto;
  final VoidCallback onToggleMenu;
  final ValueChanged<String> onAncla;
  final VoidCallback onLogin;

  const NavbarInvitado({
    super.key,
    required this.movil,
    required this.menuAbierto,
    required this.onToggleMenu,
    required this.onAncla,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xF2070D16), // rgba(7,13,22,.95)
            border: const Border(bottom: BorderSide(color: AppColors.borde)),
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
                      Row(
                        children: [
                          for (final e in enlacesNav)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: _NavLink(
                                label: e.label,
                                onTap: () => onAncla(e.ancla),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: _NavLink(
                              label: 'Iniciar Sesión',
                              destacado: true,
                              onTap: onLogin,
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

class _NavLink extends StatelessWidget {
  final String label;
  final bool destacado;
  final VoidCallback onTap;
  const _NavLink({required this.label, required this.onTap, this.destacado = false});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: destacado
                ? (hover ? AppColors.teal : AppColors.a(AppColors.teal, 0.15))
                : (hover ? AppColors.tealDim : Colors.transparent),
            borderRadius: BorderRadius.circular(8),
            border: destacado
                ? Border.all(
                    color: hover ? AppColors.teal : AppColors.a(AppColors.teal, 0.35),
                  )
                : Border.all(color: Colors.transparent),
          ),
          child: Text(
            label,
            style: AppText.poppins(
              13.12,
              weight: destacado ? FontWeight.w600 : FontWeight.w500,
              color: destacado
                  ? (hover ? AppColors.bg : AppColors.teal)
                  : (hover ? AppColors.texto : AppColors.texto2),
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

/// Menú desplegable móvil (`.navbar-links.active`).
class MenuMovilInvitado extends StatelessWidget {
  final ValueChanged<String> onAncla;
  final VoidCallback onLogin;
  const MenuMovilInvitado({super.key, required this.onAncla, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    Widget item(String label, VoidCallback onTap, {bool destacado = false}) {
      return HoverBuilder(
        builder: (context, hover) => GestureDetector(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: destacado
                  ? AppColors.a(AppColors.teal, 0.15)
                  : (hover ? AppColors.tealDim : Colors.transparent),
              borderRadius: BorderRadius.circular(8),
              border: destacado
                  ? Border.all(color: AppColors.a(AppColors.teal, 0.35))
                  : null,
            ),
            child: Text(
              label,
              style: AppText.poppins(
                13.12,
                weight: destacado ? FontWeight.w600 : FontWeight.w500,
                color: destacado ? AppColors.teal : AppColors.texto2,
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(minWidth: 192),
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
          children: [
            for (final e in enlacesNav) item(e.label, () => onAncla(e.ancla)),
            item('Iniciar Sesión', onLogin, destacado: true),
          ],
        ),
      ),
    );
  }
}
