import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Port de `.dynamic-bg` (stylePerfil.css): imagen tenue de fondo, formas
/// difuminadas, resplandores azules que se desplazan, anillos, partículas,
/// líneas y puntos decorativos.
class ProfileBackground extends StatefulWidget {
  const ProfileBackground({super.key});

  @override
  State<ProfileBackground> createState() => _ProfileBackgroundState();
}

class _ProfileBackgroundState extends State<ProfileBackground>
    with SingleTickerProviderStateMixin {
  static const int _ciclo = 3600;
  late final AnimationController _c;

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

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: AppColors.bg),
          Opacity(
            opacity: 0.15,
            child: Image.asset(
              'assets/img/fondo1.jpg',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _c,
              builder: (context, _) => CustomPaint(
                painter: _BgPainter(_c.value * _ciclo),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Glow {
  final double size, dur, delay;
  final double? top, bottom, left, right; // px o % (ver pct)
  final bool pct;
  final Color color;
  const _Glow(this.size, this.color, this.dur, this.delay,
      {this.top, this.bottom, this.left, this.right, this.pct = false});
}

class _BgPainter extends CustomPainter {
  final double t;
  _BgPainter(this.t);

  static const _azul1 = Color(0xFF3B82F6);
  static const _azul2 = Color(0xFF2563EB);
  static const _azul3 = Color(0xFF60A5FA);

  static final List<_Glow> _glows = [
    _Glow(700, _azul1.withAlpha(31), 30, 0, top: -150, left: -150),
    _Glow(550, _azul2.withAlpha(26), 35, -10, bottom: -100, right: -100),
    _Glow(600, _azul3.withAlpha(18), 40, -20, top: 30, left: 40, pct: true),
    _Glow(450, _azul1.withAlpha(20), 45, -5, top: 60, left: 5, pct: true),
    _Glow(500, _azul2.withAlpha(18), 38, -15, top: -5, right: 30, pct: true),
  ];

  static final List<List<double>> _dots = () {
    final r = math.Random(17);
    return List.generate(
      24,
      (_) => [r.nextDouble(), r.nextDouble(), 1.2 + r.nextDouble() * 1.6, r.nextDouble() * 6],
    );
  }();

  double _kf(List<double> v, double p) {
    final n = v.length - 1;
    final pos = p.clamp(0.0, 1.0).toDouble() * n;
    final i = pos.floor().clamp(0, n - 1).toInt();
    final f = Curves.easeInOut.transform(pos - i);
    return v[i] + (v[i + 1] - v[i]) * f;
  }

  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width, h = s.height;

    // ── Resplandores (glowDrift) ──
    for (final g in _glows) {
      final p = (((t - g.delay) % g.dur) + g.dur) % g.dur / g.dur;
      final dx = _kf([0, 40, -30, 0], p);
      final dy = _kf([0, -30, 20, 0], p);
      final esc = _kf([1, 1.1, 0.9, 1], p);

      final left = g.left != null
          ? (g.pct ? w * g.left! / 100 : g.left!)
          : w - (g.pct ? w * g.right! / 100 : g.right!) - g.size;
      final top = g.top != null
          ? (g.pct ? h * g.top! / 100 : g.top!)
          : h - (g.pct ? h * g.bottom! / 100 : g.bottom!) - g.size;
      final c = Offset(left + g.size / 2 + dx, top + g.size / 2 + dy);
      final r = g.size / 2 * esc;
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [g.color, g.color.withAlpha(0)],
            stops: const [0, 0.7],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
    }

    // ── Formas difuminadas (.shape, blur 60px) ──
    void forma(double size, Color color,
        {double? top, double? bottom, double? left, double? right, bool pct = false}) {
      final x = left != null
          ? (pct ? w * left / 100 : left)
          : w - (pct ? w * right! / 100 : right!) - size;
      final y = top != null
          ? (pct ? h * top / 100 : top)
          : h - (pct ? h * bottom! / 100 : bottom!) - size;
      canvas.drawCircle(
        Offset(x + size / 2, y + size / 2),
        size / 2,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30),
      );
    }

    forma(400, AppColors.a(AppColors.teal, 0.10), top: -100, right: -100);
    forma(300, AppColors.a(AppColors.amarillo, 0.07), bottom: -50, left: -50);
    forma(250, AppColors.a(AppColors.teal, 0.06), top: 50, left: 30, pct: true);
    forma(180, const Color(0xFF3B82F6).withAlpha(18), bottom: 30, right: 15, pct: true);
    forma(120, AppColors.a(AppColors.violeta, 0.06), top: 15, left: 5, pct: true);
    forma(200, AppColors.a(AppColors.teal, 0.05), top: 70, left: 70, pct: true);

    // ── Anillos ──
    void anillo(double size, Color color, double topPct, double leftOrRightPct,
        {bool derecha = false, bool pctLeft = true, bool bottom = false}) {
      final x = derecha
          ? w - w * leftOrRightPct / 100 - size
          : w * leftOrRightPct / 100;
      final y = bottom ? h - h * topPct / 100 - size : h * topPct / 100;
      canvas.drawCircle(
        Offset(x + size / 2, y + size / 2),
        size / 2,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }

    anillo(300, AppColors.a(AppColors.teal, 0.10), -5, 20, derecha: true);
    anillo(200, const Color(0xFF3B82F6).withAlpha(18), 10, 5, bottom: true);
    anillo(150, AppColors.a(AppColors.violeta, 0.06), 40, 60);

    // ── Partículas ──
    const part = [
      [0.20, 0.10, 2.0, 0.12],
      [0.85, 0.30, 3.0, 0.10],
      [0.05, 0.50, 2.0, 0.12],
      [0.60, 0.70, 4.0, 0.07],
      [0.40, 0.90, 2.0, 0.12],
    ];
    for (var i = 0; i < part.length; i++) {
      final p = part[i];
      final dy = math.sin(t * 0.8 + i * 1.7) * 8;
      canvas.drawCircle(
        Offset(w * p[0], h * p[1] + dy),
        p[2] / 2 + 0.5,
        Paint()..color = AppColors.a(AppColors.texto, p[3]),
      );
    }

    // ── Líneas decorativas (cruzan la pantalla hacia la izquierda) ──
    const lineas = [
      [0.20, 200.0, 0.05, 14.0],
      [0.45, 150.0, 0.04, 18.0],
      [0.75, 180.0, 0.05, 16.0],
    ];
    for (final l in lineas) {
      final prog = (t % l[3]) / l[3];
      final x = w - (w + l[1] * 2) * prog + l[1] * 0;
      final rect = Rect.fromLTWH(x, h * l[0], l[1], 1);
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            colors: [
              Colors.transparent,
              AppColors.a(AppColors.texto, l[2] * 2),
              Colors.transparent,
            ],
          ).createShader(rect),
      );
    }

    // ── Puntos titilantes ──
    for (final d in _dots) {
      final op = 0.15 + 0.35 * (0.5 + 0.5 * math.sin(t * 0.9 + d[3]));
      canvas.drawCircle(
        Offset(w * d[0], h * d[1]),
        d[2],
        Paint()..color = AppColors.a(AppColors.tealBrillante, op * 0.6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BgPainter old) => old.t != t;
}
