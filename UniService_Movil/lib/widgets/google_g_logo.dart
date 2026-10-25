// Archivo: google_g_logo.dart
// Responsabilidad: dibujar el logo "G" con arcos de colores para el botón de Google.
// Se usa desde: pantallas de login/registro con acceso por Google.
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Logo "G" de Google vectorial: cuatro arcos + barra azul, sin asset ni fuente.
class GoogleGLogo extends StatelessWidget {
  final double size;
  const GoogleGLogo({super.key, this.size = 18});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: _GPainter());
  }
}

class _GPainter extends CustomPainter {
  static const _rojo = Color(0xFFEA4335);
  static const _azul = Color(0xFF4285F4);
  static const _verde = Color(0xFF34A853);
  static const _amarillo = Color(0xFFFBBC05);

  double _rad(double deg) => deg * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    // Trazo = 20 % del ancho; el radio se ajusta para que el aro no se salga.
    final stroke = size.width * 0.2;
    final r = size.width / 2 - stroke / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    Paint p(Color color) => Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;

    // Ángulos elegidos a ojo para imitar el logo: rojo arriba-izq., azul der.,
    // verde abajo, amarillo abajo-izq. Los huecos dejan respirar la "G".
    canvas.drawArc(rect, _rad(-140), _rad(90), false, p(_rojo));
    canvas.drawArc(rect, _rad(-45), _rad(80), false, p(_azul));
    canvas.drawArc(rect, _rad(35), _rad(90), false, p(_verde));
    canvas.drawArc(rect, _rad(125), _rad(95), false, p(_amarillo));

    // Barra horizontal azul de la "G"
    final barra = Paint()
      ..color = _azul
      ..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(c.dx, c.dy - stroke / 2, r + stroke / 2, stroke),
      barra,
    );
  }

  // Dibujo constante: nunca hace falta repintar (el tamaño se resuelve al maquetar).
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
