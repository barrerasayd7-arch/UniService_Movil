import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

/// `.auth-lateral`: panel azul con logo, descripción, chips de categorías,
/// iconos flotantes, orbes de luz y destellos.
class AuthLateral extends StatefulWidget {
  /// En móvil (< 680px) la web oculta los chips y reduce el padding.
  final bool compacto;
  const AuthLateral({super.key, required this.compacto});

  @override
  State<AuthLateral> createState() => _AuthLateralState();
}

class _FI {
  final IconData icono;
  final double? top, bottom, left, right; // en %
  final double dur, delay, size;
  final Color color;
  const _FI(this.icono, this.dur, this.delay, this.color,
      {this.top, this.bottom, this.left, this.right, this.size = 25.6});
}

class _Orbe {
  final double size, dur, delay;
  final double? top, bottom, left, right; // px
  final double? topPct, leftPct; // %
  final Color color;
  const _Orbe(this.size, this.dur, this.delay, this.color,
      {this.top, this.bottom, this.left, this.right, this.topPct, this.leftPct});
}

class _Destello {
  final double? top, bottom, left, right; // %
  final Color color;
  final double delay;
  const _Destello(this.color, this.delay, {this.top, this.bottom, this.left, this.right});
}

class _AuthLateralState extends State<AuthLateral>
    with SingleTickerProviderStateMixin {
  static const int _ciclo = 3600;
  late final AnimationController _c;

  static const _teal = AppColors.teal;
  static const _oro = AppColors.amarillo;

  static final List<_FI> _iconos = [
    _FI(Icons.menu_book_outlined, 14, 0, _teal, top: 5, left: 8),
    _FI(Icons.code, 17, 1.5, _oro, top: 14, right: 12),
    _FI(Icons.edit_outlined, 19, 0.8, _teal.withAlpha(179), top: 38, left: 3),
    _FI(Icons.palette_outlined, 15, 2.2, _oro, top: 40, right: 6),
    _FI(Icons.inventory_2_outlined, 18, 3, _teal, bottom: 20, left: 6),
    _FI(Icons.home_outlined, 16, 1, _teal.withAlpha(153), bottom: 6, right: 8),
    _FI(Icons.school_outlined, 20, 0.3, _oro.withAlpha(128), top: 22, left: 28, size: 20.8),
    _FI(Icons.lightbulb_outline, 13, 2.8, _teal.withAlpha(128), bottom: 38, right: 3, size: 19.2),
    _FI(Icons.star_border, 22, 1.8, _oro, bottom: 10, left: 38, size: 16),
  ];

  static final List<_Orbe> _orbes = [
    _Orbe(140, 12, 0, _teal.withAlpha(128), top: -20, left: -30),
    _Orbe(180, 15, 2, _oro.withAlpha(77), bottom: -40, right: -40),
    _Orbe(120, 18, 4, _teal.withAlpha(77), topPct: 40, leftPct: 20),
  ];

  static final List<_Destello> _destellos = [
    _Destello(_teal, 0, top: 8, left: 45),
    _Destello(_oro, 0.5, top: 28, right: 20),
    _Destello(Colors.white, 1, top: 65, left: 12),
    _Destello(_teal, 1.5, top: 75, right: 28),
    _Destello(_oro, 2, top: 15, left: 60),
    _Destello(Colors.white, 0.3, top: 45, right: 15),
    _Destello(_teal, 1.2, bottom: 28, left: 18),
    _Destello(_oro, 2.5, bottom: 15, right: 35),
  ];

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: _ciclo))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  // Interpolación por tramos con ease-in-out (equivale a keyframes CSS).
  double _kf(List<double> v, double p) {
    final n = v.length - 1;
    final pos = (p.clamp(0.0, 1.0).toDouble()) * n;
    final i = pos.floor().clamp(0, n - 1).toInt();
    final f = Curves.easeInOut.transform(pos - i);
    return v[i] + (v[i + 1] - v[i]) * f;
  }

  Widget _icono(_FI it, double w, double h, double seg) {
    final local = seg - it.delay;
    final p = local < 0 ? 0.0 : (local % it.dur) / it.dur;
    final dx = _kf([0, 12, -8, 18, -6, 0], p);
    final dy = _kf([0, -14, 8, 4, -10, 0], p);
    final rot = _kf([0, 5, -3, 4, -2, 0], p) * math.pi / 180;
    final esc = _kf([1, 1.05, 0.97, 1.03, 0.98, 1], p);

    return Positioned(
      top: it.top != null ? h * it.top! / 100 : null,
      bottom: it.bottom != null ? h * it.bottom! / 100 : null,
      left: it.left != null ? w * it.left! / 100 : null,
      right: it.right != null ? w * it.right! / 100 : null,
      child: Opacity(
        opacity: 0.25,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.rotate(
            angle: rot,
            child: Transform.scale(
              scale: esc,
              child: Icon(it.icono, size: it.size, color: it.color),
            ),
          ),
        ),
      ),
    );
  }

  Widget _orbe(_Orbe o, double w, double h, double seg) {
    final local = seg - o.delay;
    final p = local < 0 ? 0.0 : (local % o.dur) / o.dur;
    final dx = _kf([0, 15, -10, 20, 0], p);
    final dy = _kf([0, -20, 12, 5, 0], p);
    final esc = _kf([1, 1.15, 0.9, 1.1, 1], p);

    return Positioned(
      top: o.top ?? (o.topPct != null ? h * o.topPct! / 100 : null),
      bottom: o.bottom,
      left: o.left ?? (o.leftPct != null ? w * o.leftPct! / 100 : null),
      right: o.right,
      width: o.size,
      height: o.size,
      child: Opacity(
        opacity: 0.35,
        child: Transform.translate(
          offset: Offset(dx, dy),
          child: Transform.scale(
            scale: esc,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [o.color, o.color.withAlpha(0)],
                  stops: const [0, 0.7],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _destello(_Destello d, double w, double h, double seg) {
    final local = seg - d.delay;
    final u = local < 0 ? 0.0 : (local % 3) / 3;
    final s = math.sin(u * math.pi); // 0 -> 1 -> 0
    return Positioned(
      top: d.top != null ? h * d.top! / 100 : null,
      bottom: d.bottom != null ? h * d.bottom! / 100 : null,
      left: d.left != null ? w * d.left! / 100 : null,
      right: d.right != null ? w * d.right! / 100 : null,
      child: Opacity(
        opacity: 0.7 * s,
        child: Transform.scale(
          scale: 0.5 + 0.8 * s,
          child: Container(
            width: 3,
            height: 3,
            decoration: BoxDecoration(color: d.color, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final compacto = widget.compacto;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment(-0.34, -0.94),
          end: Alignment(0.34, 0.94),
          stops: [0, 0.3, 0.55, 1],
          colors: [
            Color(0xFF0A1E35),
            Color(0xFF0C2F4A),
            Color(0xFF0A3D5C),
            Color(0xFF0D2E4A),
          ],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Resplandores de fondo (radial teal arriba-izq, amarillo abajo-der)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.6, -0.6),
                  radius: 0.9,
                  colors: [AppColors.a(_teal, 0.12), Colors.transparent],
                  stops: const [0, 0.5],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.6, 0.6),
                  radius: 0.9,
                  colors: [AppColors.a(_oro, 0.06), Colors.transparent],
                  stops: const [0, 0.5],
                ),
              ),
            ),
          ),

          // Capa animada (iconos, orbes, destellos)
          Positioned.fill(
            child: IgnorePointer(
              child: LayoutBuilder(
                builder: (context, box) {
                  // El Stack está dentro del padding; usamos el ancho/alto reales.
                  final w = box.maxWidth;
                  final h = box.maxHeight;
                  return AnimatedBuilder(
                    animation: _c,
                    builder: (context, _) {
                      final seg = _c.value * _ciclo;
                      return Stack(
                        clipBehavior: Clip.none,
                        children: [
                          for (final o in _orbes) _orbe(o, w, h, seg),
                          for (final it in _iconos) _icono(it, w, h, seg),
                          for (final d in _destellos) _destello(d, w, h, seg),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),

          // Contenido
          Padding(
            padding: EdgeInsets.symmetric(vertical: compacto ? 36 : 32, horizontal: 28),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LogoCircular(),
              const SizedBox(height: 18),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: 'Uni',
                      style: AppText.poppins(
                        24,
                        weight: FontWeight.w700,
                        color: AppColors.teal,
                        height: 1.25,
                      ),
                    ),
                    TextSpan(
                      text: 'Service',
                      style: AppText.poppins(
                        24,
                        weight: FontWeight.w700,
                        color: AppColors.amarillo,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 260),
                child: Text(
                  'Intercambia tutorías, proyectos, diseño y más con otros estudiantes universitarios.',
                  textAlign: TextAlign.center,
                  style: AppText.poppins(
                    13.12,
                    color: Colors.white.withAlpha(140),
                    height: 1.65,
                  ),
                ),
              ),
              if (!compacto) ...[
                const SizedBox(height: 18),
                const _ChipsCategorias(),
              ],
            ],
          ),
          ),
        ],
      ),
    );
  }
}

class _LogoCircular extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 76,
      height: 76,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.a(AppColors.teal, 0.12),
        border: Border.all(color: AppColors.a(AppColors.teal, 0.35), width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.a(AppColors.teal, 0.08),
            blurRadius: 30,
          ),
        ],
      ),
      child: Image.asset(
        'assets/img/logo_color_noBG.png',
        width: 76,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _ChipsCategorias extends StatelessWidget {
  const _ChipsCategorias();

  static const _items = [
    (Icons.menu_book_outlined, 'Tutorías'),
    (Icons.code, 'Programación'),
    (Icons.edit_outlined, 'Ensayos'),
    (Icons.palette_outlined, 'Diseño'),
    (Icons.inventory_2_outlined, 'Productos'),
    (Icons.home_outlined, 'Arriendo'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final (icono, texto) in _items)
          HoverBuilder(
            cursor: SystemMouseCursors.basic,
            builder: (context, hover) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              transform: Matrix4.translationValues(0, hover ? -2 : 0, 0),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.a(AppColors.teal, hover ? 0.16 : 0.08),
                border: Border.all(
                  color: AppColors.a(AppColors.teal, hover ? 0.35 : 0.18),
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icono,
                    size: 12,
                    color: AppColors.a(AppColors.teal, hover ? 1 : 0.75),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    texto,
                    style: AppText.poppins(
                      11.52,
                      weight: FontWeight.w500,
                      color: AppColors.a(AppColors.teal, hover ? 1 : 0.75),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
