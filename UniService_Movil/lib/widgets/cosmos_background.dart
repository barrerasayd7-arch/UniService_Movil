import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Port de `.cosmos-scene` (StyleLogin.css): portal cósmico con anillos
/// geométricos rotando en 3D, rayos de luz, puntos orbitando y estrellas.
/// En la web se oculta en pantallas < 680px; aquí se muestra desde la pantalla.
class CosmosBackground extends StatefulWidget {
  const CosmosBackground({super.key});

  @override
  State<CosmosBackground> createState() => _CosmosBackgroundState();
}

class _CosmosBackgroundState extends State<CosmosBackground>
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
          // Degradado base + resplandores
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                stops: [0, 0.4, 0.7, 1],
                colors: [
                  Color(0xFF070D16),
                  Color(0xFF0A1628),
                  Color(0xFF0E1F3A),
                  Color(0xFF081220),
                ],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(-0.4, -0.6),
                radius: 0.9,
                colors: [AppColors.a(AppColors.teal, 0.08), Colors.transparent],
                stops: const [0, 0.6],
              ),
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0.4, 0.6),
                radius: 0.8,
                colors: [AppColors.a(AppColors.amarillo, 0.04), Colors.transparent],
                stops: const [0, 0.5],
              ),
            ),
          ),
          // Anillos, puntos, estrellas
          AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              painter: _CosmosPainter(_c.value * _ciclo),
            ),
          ),
          // Viñeta
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                radius: 0.85,
                colors: [Colors.transparent, AppColors.a(AppColors.bg, 0.65)],
                stops: const [0.3, 1],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Ring {
  final double size;
  final Color borde;
  final double grosor;
  final Color bordeDiagonal;
  final double rx, ry, rz; // grados totales por ciclo
  final double dur;
  final bool reversa;
  const _Ring(this.size, this.borde, this.grosor, this.bordeDiagonal, this.rx,
      this.ry, this.rz, this.dur, this.reversa);
}

class _CosmosPainter extends CustomPainter {
  final double t;
  _CosmosPainter(this.t);

  static const _teal = Color(0xFF0EA5A0);
  static const _oro = Color(0xFFF5C842);
  static const _violeta = Color(0xFF6450C8);

  // r1..r7 de StyleLogin.css
  static final List<_Ring> _anillos = [
    _Ring(1500, _teal.withAlpha(31), 2, _teal.withAlpha(13), 720, 360, 720, 120, false),
    _Ring(1300, _oro.withAlpha(26), 2, _oro.withAlpha(10), 360, 720, 360, 100, true),
    _Ring(1100, _violeta.withAlpha(26), 2, _teal.withAlpha(15), 540, 360, 540, 90, false),
    _Ring(900, _teal.withAlpha(33), 1.5, _oro.withAlpha(15), 360, 540, 360, 110, true),
    _Ring(700, _oro.withAlpha(26), 1.5, _teal.withAlpha(20), 360, 360, 720, 70, false),
    _Ring(520, _teal.withAlpha(41), 2, _oro.withAlpha(18), 720, 180, 360, 80, true),
    _Ring(340, _oro.withAlpha(38), 1.5, _teal.withAlpha(31), 360, 360, 360, 80, false),
  ];

  static final List<List<double>> _estrellas = () {
    final r = math.Random(9);
    return List.generate(
      35,
      (_) => [
        r.nextDouble(), // x
        r.nextDouble(), // y
        1 + r.nextDouble() * 1.6, // radio
        3.5 + r.nextDouble() * 2, // duración
        r.nextDouble() * 4, // delay
      ],
    );
  }();

  static final List<List<double>> _puntos = () {
    final r = math.Random(4);
    return List.generate(
      30,
      (_) => [
        (r.nextDouble() * 2 - 1) * 600, // x relativo al centro
        (r.nextDouble() * 2 - 1) * 540, // y relativo al centro
        55 + r.nextDouble() * 25, // duración
        r.nextDouble() * 20, // delay
      ],
    );
  }();

  Offset _proyectar(double x, double y, double z, Offset c) {
    const persp = 1200.0;
    final f = persp / (persp - z).clamp(80.0, 100000.0);
    return Offset(c.dx + x * f, c.dy + y * f);
  }

  List<double> _rotar3d(double x, double y, double rx, double ry, double rz) {
    // CSS: rotateX rotateY rotateZ  =>  p' = Rx * Ry * Rz * p
    final x1 = x * math.cos(rz) - y * math.sin(rz);
    final y1 = x * math.sin(rz) + y * math.cos(rz);
    const z1 = 0.0;
    final x2 = x1 * math.cos(ry) + z1 * math.sin(ry);
    final z2 = -x1 * math.sin(ry) + z1 * math.cos(ry);
    final y3 = y1 * math.cos(rx) - z2 * math.sin(rx);
    final z3 = y1 * math.sin(rx) + z2 * math.cos(rx);
    return [x2, y3, z3];
  }

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);

    // ── Anillos 3D ──
    for (final ring in _anillos) {
      var prog = (t / ring.dur) % 1;
      if (ring.reversa) prog = 1 - prog;
      final rx = ring.rx * prog * math.pi / 180;
      final ry = ring.ry * prog * math.pi / 180;
      final rz = ring.rz * prog * math.pi / 180;
      final h = ring.size / 2;

      void cuadrado(double lado, double giro, Paint paint) {
        final hh = lado / 2;
        final base = [
          [-hh, -hh],
          [hh, -hh],
          [hh, hh],
          [-hh, hh],
        ];
        final path = Path();
        for (var i = 0; i < 4; i++) {
          final px = base[i][0] * math.cos(giro) - base[i][1] * math.sin(giro);
          final py = base[i][0] * math.sin(giro) + base[i][1] * math.cos(giro);
          final r = _rotar3d(px, py, rx, ry, rz);
          final o = _proyectar(r[0], r[1], r[2], c);
          if (i == 0) {
            path.moveTo(o.dx, o.dy);
          } else {
            path.lineTo(o.dx, o.dy);
          }
        }
        path.close();
        canvas.drawPath(path, paint);
      }

      cuadrado(
        h * 2,
        0,
        Paint()
          ..color = ring.borde
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.grosor,
      );
      cuadrado(
        h * 2,
        math.pi / 4,
        Paint()
          ..color = ring.bordeDiagonal
          ..style = PaintingStyle.stroke
          ..strokeWidth = ring.grosor * 0.75,
      );
    }

    // ── Núcleo pulsante ──
    final pulso = 0.5 + 0.5 * math.sin(t * 2 * math.pi / 20);
    canvas.drawCircle(
      c,
      60 + pulso * 25,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.a(AppColors.teal, 0.20),
            AppColors.a(AppColors.teal, 0.0),
          ],
        ).createShader(Rect.fromCircle(center: c, radius: 85)),
    );
    canvas.drawCircle(
      c,
      6,
      Paint()
        ..shader = RadialGradient(
          colors: [
            AppColors.teal,
            AppColors.a(AppColors.teal, 0.3),
            Colors.transparent,
          ],
          stops: const [0, 0.3, 0.7],
        ).createShader(Rect.fromCircle(center: c, radius: 8)),
    );

    // ── Puntos orbitando (salen del centro hacia su destino) ──
    for (final p in _puntos) {
      final local = t - p[3];
      if (local < 0) continue;
      final prog = (local % p[2]) / p[2];
      final o = Offset(c.dx + p[0] * prog, c.dy + p[1] * prog);
      final op = math.sin(prog * math.pi);
      canvas.drawCircle(
        o,
        1.4,
        Paint()..color = AppColors.a(AppColors.teal, 0.7 * op),
      );
    }

    // ── Estrellas parpadeando ──
    for (final s in _estrellas) {
      final local = t - s[4];
      if (local < 0) continue;
      var u = (local / s[3]) % 2;
      if (u > 1) u = 2 - u;
      final op = 0.1 + 0.9 * math.sin(u * math.pi);
      canvas.drawCircle(
        Offset(s[0] * size.width, s[1] * size.height),
        s[2] * (0.6 + 0.6 * u),
        Paint()..color = Colors.white.withAlpha((op.clamp(0.0, 1.0) * 255).round()),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CosmosPainter old) => old.t != t;
}
