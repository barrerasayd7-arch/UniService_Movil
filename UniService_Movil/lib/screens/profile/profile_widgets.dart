import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// Aparece desde abajo con fundido (@keyframes fadeInUp).
class FadeInUp extends StatelessWidget {
  final Widget child;
  final int delayMs;
  const FadeInUp({super.key, required this.child, this.delayMs = 0});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 600 + delayMs),
      curve: Interval(delayMs / (600 + delayMs), 1, curve: Curves.easeOut),
      builder: (context, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 30), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// .stat-item
// ─────────────────────────────────────────────────────────────
class StatItem extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const StatItem({super.key, required this.value, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, hover ? -3 : 0, 0),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 10),
          decoration: BoxDecoration(
            color: hover ? AppColors.tealDim : AppColors.bg2,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              Text(
                value,
                style: AppText.poppins(24, weight: FontWeight.w800, color: AppColors.teal),
              ),
              const SizedBox(height: 4),
              Text(
                label.toUpperCase(),
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  11.52,
                  weight: FontWeight.w600,
                  color: AppColors.texto3,
                  spacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// .info-item
// ─────────────────────────────────────────────────────────────
class InfoItem extends StatelessWidget {
  final String label;
  final String value;
  const InfoItem({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: SystemMouseCursors.basic,
      builder: (context, hover) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: hover ? AppColors.bg3 : AppColors.bg2,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: AppText.poppins(12, color: AppColors.texto3, spacing: 0.5),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: AppText.poppins(16, weight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// .menu-item (con icono, título, descripción y flecha)
// ─────────────────────────────────────────────────────────────
class MenuItem extends StatelessWidget {
  final IconData icono;
  final Color? colorIcono;
  final String title;
  final String? desc;
  final VoidCallback? onTap;
  final bool danger;

  /// Contenido extra a la derecha (botones de acción en "Mis servicios").
  final Widget? trailing;
  final bool mostrarFlecha;
  final Widget? leading; // reemplaza al icono (p. ej. avatar)

  const MenuItem({
    super.key,
    required this.icono,
    required this.title,
    this.colorIcono,
    this.desc,
    this.onTap,
    this.danger = false,
    this.trailing,
    this.mostrarFlecha = true,
    this.leading,
  });

  static const _rojo = Color(0xFFEF4444);
  static const _rojoClaro = Color(0xFFF87171);

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      cursor: onTap == null ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hover) {
        final h = hover && onTap != null;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: Matrix4.translationValues(h ? 5 : 0, 0, 0),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: h ? AppColors.tealDim : AppColors.bg2,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: h
                    ? AppColors.teal
                    : (danger ? AppColors.a(_rojo, 0.3) : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                leading ??
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: h
                            ? AppColors.teal
                            : (danger ? AppColors.a(_rojo, 0.15) : AppColors.bg3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        icono,
                        size: 18,
                        color: colorIcono ?? (h ? AppColors.bg : AppColors.texto),
                      ),
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.poppins(
                          14.4,
                          weight: FontWeight.w600,
                          color: danger ? _rojoClaro : AppColors.texto,
                        ),
                      ),
                      if (desc != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            desc!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.poppins(12, color: AppColors.texto3),
                          ),
                        ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 8), trailing!],
                if (mostrarFlecha && trailing == null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      transform: Matrix4.translationValues(h ? 3 : 0, 0, 0),
                      child: Text(
                        '→',
                        style: AppText.poppins(
                          12.8,
                          color: danger
                              ? _rojoClaro
                              : (h ? AppColors.teal : AppColors.texto3),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// .menu-section + .section-title
// ─────────────────────────────────────────────────────────────
class MenuSection extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final Widget child;
  const MenuSection({
    super.key,
    required this.icono,
    required this.titulo,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borde),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.alphaBlend(AppColors.a(AppColors.teal, 0.10), AppColors.card),
          ],
        ),
      ),
      child: Stack(
        children: [
          // Adornos: resplandor teal arriba-derecha, amarillo abajo-izquierda
          Positioned(
            top: -50,
            right: -50,
            child: _Mancha(120, AppColors.teal, 0.08),
          ),
          Positioned(
            bottom: -40,
            left: -40,
            child: _Mancha(80, AppColors.amarillo, 0.06),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icono, size: 14, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text(
                    titulo.toUpperCase(),
                    style: AppText.poppins(
                      11.52,
                      weight: FontWeight.w700,
                      color: AppColors.teal,
                      spacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Container(height: 1, color: AppColors.borde)),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ],
      ),
    );
  }
}

class _Mancha extends StatelessWidget {
  final double size;
  final Color color;
  final double opacidad;
  const _Mancha(this.size, this.color, this.opacidad);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [AppColors.a(color, opacidad), Colors.transparent],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// .btn-action (Editar, Compartir, Seguir, Chatear)
// ─────────────────────────────────────────────────────────────
enum EstiloAccion { solido, outline, oscuro, sutil }

class BtnAction extends StatelessWidget {
  final String label;
  final IconData icono;
  final EstiloAccion estilo;
  final VoidCallback? onTap;
  const BtnAction({
    super.key,
    required this.label,
    required this.icono,
    required this.onTap,
    this.estilo = EstiloAccion.solido,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) {
        final h = hover && onTap != null;
        Color bg, fg, borde;
        switch (estilo) {
          case EstiloAccion.solido:
            bg = h ? AppColors.teal2 : AppColors.teal;
            fg = AppColors.bg;
            borde = bg;
          case EstiloAccion.outline:
            bg = h ? AppColors.tealDim : Colors.transparent;
            fg = AppColors.teal;
            borde = AppColors.teal;
          case EstiloAccion.oscuro:
            bg = h ? AppColors.tealDim : AppColors.bg2;
            fg = h ? AppColors.teal : AppColors.texto;
            borde = h ? AppColors.teal : AppColors.borde;
          case EstiloAccion.sutil:
            bg = AppColors.bg2;
            fg = h ? AppColors.texto : AppColors.texto2;
            borde = h ? AppColors.borde2 : AppColors.borde;
        }
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: Matrix4.translationValues(0, h ? -2 : 0, 0),
            constraints: const BoxConstraints(minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borde),
              boxShadow: h && estilo == EstiloAccion.solido
                  ? [
                      BoxShadow(
                        color: AppColors.a(AppColors.teal, 0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icono, size: 16, color: fg),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.poppins(13.12, weight: FontWeight.w600, color: fg),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
