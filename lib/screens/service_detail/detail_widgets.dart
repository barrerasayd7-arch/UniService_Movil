import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// `.seccion-info`: tarjeta con título (borde inferior teal) y contenido.
class SeccionInfo extends StatelessWidget {
  final IconData? icono;
  final String? titulo;
  final Widget child;
  final EdgeInsets margen;
  const SeccionInfo({
    super.key,
    required this.child,
    this.icono,
    this.titulo,
    this.margen = const EdgeInsets.only(bottom: 24),
  });

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= 540;
    return Container(
      width: double.infinity,
      margin: margen,
      padding: EdgeInsets.all(movil ? 16 : 24),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titulo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.only(bottom: 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: AppColors.teal, width: 2)),
              ),
              child: Row(
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 17, color: AppColors.texto),
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      titulo!,
                      style: AppText.poppins(16, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
          child,
        ],
      ),
    );
  }
}

/// `.info-row`: etiqueta a la izquierda y valor teal a la derecha.
class InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? iconoValor;
  final bool ultima;
  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.iconoValor,
    this.ultima = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: ultima ? null : const Border(bottom: BorderSide(color: AppColors.borde)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            label,
            style: AppText.poppins(14.08, weight: FontWeight.w500, color: AppColors.texto2),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (iconoValor != null) ...[
                  Icon(iconoValor, size: 14, color: AppColors.teal),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    value,
                    textAlign: TextAlign.right,
                    style: AppText.poppins(14.08, weight: FontWeight.w700, color: AppColors.teal),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum EstiloBtn { principal, whatsapp, gmail, secundario, mapa }

/// Botones del detalle: `.btn-primary`, `.btn-secondary`, `.btn-whatsapp`,
/// `.btn-gmail` y `.btn-ver-mapa`.
class BtnDetalle extends StatelessWidget {
  final String label;
  final IconData? icono;
  final VoidCallback? onTap;
  final EstiloBtn estilo;
  final bool cargando;
  final bool ancho; // ocupa todo el ancho
  final bool margenInferior;

  const BtnDetalle({
    super.key,
    required this.label,
    required this.onTap,
    this.icono,
    this.estilo = EstiloBtn.principal,
    this.cargando = false,
    this.ancho = true,
    this.margenInferior = true,
  });

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onTap == null || cargando;

    return HoverBuilder(
      cursor: deshabilitado ? SystemMouseCursors.basic : SystemMouseCursors.click,
      builder: (context, hover) {
        final h = hover && !deshabilitado;

        Color fg;
        Color? bg;
        Gradient? grad;
        Border? borde;
        List<BoxShadow> sombra;
        double padV = 13;
        FontWeight peso = FontWeight.w700;
        double radio = 12;

        switch (estilo) {
          case EstiloBtn.principal:
            bg = h ? AppColors.teal2 : AppColors.teal;
            fg = AppColors.bg;
            sombra = [
              BoxShadow(
                color: AppColors.a(AppColors.teal, h ? 0.3 : 0.2),
                blurRadius: h ? 20 : 12,
                offset: Offset(0, h ? 8 : 4),
              ),
            ];
          case EstiloBtn.secundario:
            bg = h ? AppColors.a(AppColors.teal, 0.05) : Colors.transparent;
            fg = h ? AppColors.teal : AppColors.texto;
            borde = Border.all(color: h ? AppColors.teal : AppColors.borde, width: 2);
            sombra = const [];
            peso = FontWeight.w600;
          case EstiloBtn.whatsapp:
            grad = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF25D366), Color(0xFF128C7E)],
            );
            fg = Colors.white;
            padV = 14;
            peso = FontWeight.w600;
            sombra = [
              BoxShadow(
                color: const Color(0xFF25D366).withAlpha(h ? 102 : 77),
                blurRadius: h ? 24 : 16,
                offset: Offset(0, h ? 8 : 4),
              ),
            ];
          case EstiloBtn.gmail:
            grad = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFEA4335), Color(0xFFD93025)],
            );
            fg = Colors.white;
            padV = 14;
            peso = FontWeight.w600;
            sombra = [
              BoxShadow(
                color: const Color(0xFFEA4335).withAlpha(h ? 102 : 77),
                blurRadius: h ? 24 : 16,
                offset: Offset(0, h ? 8 : 4),
              ),
            ];
          case EstiloBtn.mapa:
            grad = const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF0EA5A0), Color(0xFF0C8D89)],
            );
            fg = Colors.white;
            padV = 12;
            peso = FontWeight.w600;
            sombra = [
              BoxShadow(
                color: AppColors.a(AppColors.teal, h ? 0.4 : 0.3),
                blurRadius: h ? 20 : 15,
                offset: Offset(0, h ? 6 : 4),
              ),
            ];
        }

        final contenido = Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: ancho ? MainAxisSize.max : MainAxisSize.min,
          children: [
            if (cargando)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                ),
              )
            else if (icono != null)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Icon(icono, size: 17, color: fg),
              ),
            Flexible(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: AppText.poppins(15.2, weight: peso, color: fg),
              ),
            ),
          ],
        );

        return GestureDetector(
          onTap: deshabilitado ? null : onTap,
          child: Opacity(
            opacity: cargando ? 0.7 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.translationValues(0, h ? -2 : 0, 0),
              width: ancho ? double.infinity : null,
              margin: EdgeInsets.only(bottom: margenInferior ? 12 : 0),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: padV),
              decoration: BoxDecoration(
                color: bg,
                gradient: grad,
                borderRadius: BorderRadius.circular(radio),
                border: borde,
                boxShadow: sombra,
              ),
              child: contenido,
            ),
          ),
        );
      },
    );
  }
}
