import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Port de Components/HeroTesseract.jsx (three.js) a CustomPainter:
/// hipercubo 4D rotando + cubo interior + símbolo infinito + partículas.
class TesseractBackground extends StatefulWidget {
  const TesseractBackground({super.key});

  @override
  State<TesseractBackground> createState() => _TesseractBackgroundState();
}

class _TesseractBackgroundState extends State<TesseractBackground>
    with SingleTickerProviderStateMixin {
  static const int _segundosCiclo = 3600;
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _segundosCiclo),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, box) {
          // Misma tabla responsive que HeroTesseract.jsx (tema oscuro)
          final w = MediaQuery.of(context).size.width;
          double s, x, y;
          if (w < 640) {
            s = 1;
            x = 0;
            y = 1.6;
          } else if (w < 900) {
            s = 1.3;
            x = 0.8;
            y = 1.5;
          } else if (w < 1200) {
            s = 1.6;
            x = 1.8;
            y = 0.8;
          } else {
            s = 2;
            x = 3;
            y = 0.3;
          }
          return AnimatedBuilder(
            animation: _c,
            builder: (context, _) => CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _TesseractPainter(
                t: _c.value * _segundosCiclo,
                escala: s,
                posX: x,
                posY: y,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TesseractPainter extends CustomPainter {
  final double t;
  final double escala;
  final double posX;
  final double posY;

  _TesseractPainter({
    required this.t,
    required this.escala,
    required this.posX,
    required this.posY,
  });

  static const double _camZ = 5;
  static const double _tanHalfFov = 0.4663; // fov ~50°

  // 16 vértices del hipercubo
  static final List<List<double>> _verts = List.generate(16, (i) {
    return [
      (i & 1) != 0 ? 1.0 : -1.0,
      (i & 2) != 0 ? 1.0 : -1.0,
      (i & 4) != 0 ? 1.0 : -1.0,
      (i & 8) != 0 ? 1.0 : -1.0,
    ];
  });

  // 32 aristas (vértices que difieren en una sola coordenada)
  static final List<List<int>> _aristas = () {
    final out = <List<int>>[];
    for (var i = 0; i < 16; i++) {
      for (var j = i + 1; j < 16; j++) {
        var diff = 0;
        for (var k = 0; k < 4; k++) {
          if (_verts[i][k] != _verts[j][k]) diff++;
        }
        if (diff == 1) out.add([i, j]);
      }
    }
    return out;
  }();

  // Partículas de fondo (fijas)
  static final List<List<double>> _particulas = () {
    final r = math.Random(3);
    return List.generate(
      140,
      (_) => [r.nextDouble(), r.nextDouble(), 0.5 + r.nextDouble() * 1.2],
    );
  }();

  /// Proyecta un punto 3D (ya escalado y desplazado) a pantalla.
  Offset _pantalla(Size size, double x, double y, double z, double pxPorUnidad) {
    final f = _camZ / (_camZ - z);
    return Offset(
      size.width / 2 + x * f * pxPorUnidad,
      size.height / 2 - y * f * pxPorUnidad,
    );
  }

  @override
  void paint(Canvas canvas, Size size) {
    final pxPorUnidad = (size.height / 2) / (_camZ * _tanHalfFov);
    final color = AppColors.tealBrillante;

    // ── Partículas ──
    final pPart = Paint()..color = AppColors.a(color, 0.35);
    for (final p in _particulas) {
      canvas.drawCircle(
        Offset(p[0] * size.width, p[1] * size.height),
        p[2],
        pPart,
      );
    }

    // ── Tesseract ──
    final angXW = t * 0.035;
    final angYZ = t * 0.06125;
    final cosXW = math.cos(angXW), sinXW = math.sin(angXW);
    final cosYZ = math.cos(angYZ), sinYZ = math.sin(angYZ);

    final proyectados = <List<double>>[];
    for (final v in _verts) {
      final x1 = v[0] * cosXW - v[3] * sinXW;
      final w1 = v[0] * sinXW + v[3] * cosXW;
      final y1 = v[1] * cosYZ - v[2] * sinYZ;
      final z1 = v[1] * sinYZ + v[2] * cosYZ;
      const d = 3.5;
      final sc = 1.8 / (w1 + d);
      proyectados.add([x1 * sc, y1 * sc, z1 * sc]);
    }

    List<double> mundo(List<double> p) =>
        [p[0] * escala + posX, p[1] * escala + posY, p[2] * escala];

    final lineas = Paint()
      ..color = AppColors.a(color, 0.7)
      ..strokeWidth = 1.1
      ..style = PaintingStyle.stroke;

    for (final a in _aristas) {
      final p1 = mundo(proyectados[a[0]]);
      final p2 = mundo(proyectados[a[1]]);
      canvas.drawLine(
        _pantalla(size, p1[0], p1[1], p1[2], pxPorUnidad),
        _pantalla(size, p2[0], p2[1], p2[2], pxPorUnidad),
        lineas,
      );
    }

    final puntos = Paint()..color = color;
    for (final pv in proyectados) {
      final m = mundo(pv);
      final prof = _camZ - m[2];
      final diametro = 0.12 * (size.height / 2) / prof;
      canvas.drawCircle(
        _pantalla(size, m[0], m[1], m[2], pxPorUnidad),
        diametro / 2,
        puntos,
      );
    }

    // ── Cubo interior (tenue, rota lento) ──
    _dibujarCuboInterior(canvas, size, pxPorUnidad, color);

    // ── Símbolo infinito en el centro del tesseract ──
    _dibujarInfinito(canvas, size, pxPorUnidad, color);
  }

  List<double> _rotar(double x, double y, double z, double rx, double ry, double rz) {
    // Rotación Z, luego Y, luego X
    var x1 = x * math.cos(rz) - y * math.sin(rz);
    var y1 = x * math.sin(rz) + y * math.cos(rz);
    var z1 = z;
    final x2 = x1 * math.cos(ry) + z1 * math.sin(ry);
    final z2 = -x1 * math.sin(ry) + z1 * math.cos(ry);
    final y3 = y1 * math.cos(rx) - z2 * math.sin(rx);
    final z3 = y1 * math.sin(rx) + z2 * math.cos(rx);
    return [x2, y3, z3];
  }

  void _dibujarCuboInterior(Canvas canvas, Size size, double pxPorUnidad, Color color) {
    const cubo = [
      [-1, -1, -1], [1, -1, -1], [1, -1, 1], [-1, -1, 1],
      [-1, 1, -1], [1, 1, -1], [1, 1, 1], [-1, 1, 1],
    ];
    const aristas = [
      [0, 1], [1, 2], [2, 3], [3, 0],
      [4, 5], [5, 6], [6, 7], [7, 4],
      [0, 4], [1, 5], [2, 6], [3, 7],
    ];
    const tam = 0.45;
    final pts = cubo.map((v) {
      final r = _rotar(
        v[0] * tam,
        v[1] * tam,
        v[2] * tam,
        t * 0.05,
        t * 0.08,
        0,
      );
      return [
        r[0] * escala + posX,
        r[1] * escala + posY,
        r[2] * escala,
      ];
    }).toList();

    final l = Paint()
      ..color = AppColors.a(color, 0.15)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    for (final a in aristas) {
      final p1 = pts[a[0]];
      final p2 = pts[a[1]];
      canvas.drawLine(
        _pantalla(size, p1[0], p1[1], p1[2], pxPorUnidad),
        _pantalla(size, p2[0], p2[1], p2[2], pxPorUnidad),
        l,
      );
    }
    final d = Paint()..color = AppColors.a(color, 0.5);
    for (final p in pts) {
      canvas.drawCircle(_pantalla(size, p[0], p[1], p[2], pxPorUnidad), 2, d);
    }
  }

  void _dibujarInfinito(Canvas canvas, Size size, double pxPorUnidad, Color color) {
    const a = 0.5;
    const grupoEscala = 0.3;
    final rx = t * 0.15;
    final rz = t * 0.1;

    Offset punto(double ang) {
      final den = 1 + math.sin(ang) * math.sin(ang);
      final px = a * math.cos(ang) / den * grupoEscala;
      final py = a * math.sin(ang) * math.cos(ang) / den * grupoEscala;
      final r = _rotar(px, py, 0, rx, 0, rz);
      return _pantalla(
        size,
        r[0] * escala + posX,
        r[1] * escala + posY,
        r[2] * escala,
        pxPorUnidad,
      );
    }

    final path = Path();
    for (var i = 0; i <= 100; i++) {
      final ang = i / 100 * math.pi * 2;
      final o = punto(ang);
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.a(color, 0.9)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );

    // Dos destellos que recorren la curva en sentidos opuestos
    final p1 = (t * 0.112) % 1;
    final p2 = ((0.5 - t * 0.112) % 1 + 1) % 1;
    final destello = Paint()..color = AppColors.a(color, 0.6);
    canvas.drawCircle(punto(p1 * math.pi * 2), 3, destello);
    canvas.drawCircle(punto(p2 * math.pi * 2), 3, destello);
  }

  @override
  bool shouldRepaint(covariant _TesseractPainter old) =>
      old.t != t || old.escala != escala || old.posX != posX || old.posY != posY;
}
