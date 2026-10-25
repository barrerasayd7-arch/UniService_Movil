// Archivo: section_backgrounds.dart
// Responsabilidad: contenedor de sección con fondos decorativos (grilla, circuito, estrellas) y resplandores.
// Se usa desde: secciones que replican el estilo `.seccion` / `.seccion-oscura` de la web.

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Motivo decorativo dibujado detrás del contenido de la sección.
enum FondoSeccion { ninguno, grilla, circuito, estrellas }

/// Equivalente a `.seccion` / `.seccion-oscura` + `.bg-canvas-*`.
/// [oscura] aplica el degradado azul con los dos resplandores (teal / violeta);
/// [fondo] elige el patrón de líneas y [child] es el contenido de la sección.
class SeccionFondo extends StatelessWidget {
  final bool oscura;
  final FondoSeccion fondo;
  final Widget child;

  const SeccionFondo({
    super.key,
    required this.child,
    this.oscura = false,
    this.fondo = FondoSeccion.ninguno,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      clipBehavior: Clip.hardEdge,
      decoration: BoxDecoration(
        color: oscura ? null : AppColors.bg,
        gradient: oscura
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.bg2, Color(0xFF0D1F33), AppColors.bg2],
              )
            : null,
      ),
      child: Stack(
        children: [
          if (oscura) ...[
            Positioned(
              top: -200,
              right: -120,
              child: _Resplandor(
                size: 440,
                color: AppColors.a(AppColors.teal, 0.15),
              ),
            ),
            Positioned(
              bottom: -120,
              left: -80,
              child: _Resplandor(
                size: 340,
                color: AppColors.a(AppColors.violeta, 0.10),
              ),
            ),
          ],
          if (fondo != FondoSeccion.ninguno)
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _painterPara(fondo)),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 52),
            child: child,
          ),
        ],
      ),
    );
  }

  CustomPainter _painterPara(FondoSeccion f) {
    switch (f) {
      case FondoSeccion.grilla:
        return _GridLinesPainter();
      case FondoSeccion.circuito:
        return _CircuitPainter();
      case FondoSeccion.estrellas:
        return _StarsPainter();
      case FondoSeccion.ninguno:
        return _GridLinesPainter();
    }
  }
}

// Mancha circular difusa que simula un resplandor de luz en una esquina.
class _Resplandor extends StatelessWidget {
  final double size;
  final Color color;
  const _Resplandor({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, Colors.transparent],
          stops: const [0, 0.7],
        ),
      ),
    );
  }
}

// Grilla tenue de 60 px, usada como textura base de las secciones claras.
class _GridLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = AppColors.a(AppColors.teal, 0.05)
      ..strokeWidth = 1;
    const step = 60.0;
    for (double x = 0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Trazos ortogonales con nodos, tipo placa de circuito; usa una semilla fija
// para que el patrón no cambie entre repintados.
class _CircuitPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(11);
    const step = 60.0;
    final linea = Paint()
      ..color = AppColors.a(AppColors.teal, 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
    final nodo = Paint()..color = AppColors.a(AppColors.teal, 0.14);

    final cols = (size.width / step).floor().clamp(1, 1000).toInt();
    final rows = (size.height / step).floor().clamp(1, 1000).toInt();

    for (var i = 0; i < 16; i++) {
      var x = rnd.nextInt(cols + 1) * step;
      var y = rnd.nextInt(rows + 1) * step;
      final path = Path()..moveTo(x, y);
      canvas.drawCircle(Offset(x, y), 2.5, nodo);
      final tramos = 2 + rnd.nextInt(3);
      var horizontal = rnd.nextBool();
      for (var t = 0; t < tramos; t++) {
        final largo = (1 + rnd.nextInt(3)) * step * (rnd.nextBool() ? 1 : -1);
        if (horizontal) {
          x = (x + largo).clamp(0.0, size.width).toDouble();
        } else {
          y = (y + largo).clamp(0.0, size.height).toDouble();
        }
        path.lineTo(x, y);
        horizontal = !horizontal;
      }
      canvas.drawPath(path, linea);
      canvas.drawCircle(Offset(x, y), 2.5, nodo);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Puntos blancos de tamaño y opacidad variables, como un cielo estrellado.
class _StarsPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(5);
    for (var i = 0; i < 80; i++) {
      final p = Paint()
        ..color = Colors.white.withAlpha(
          ((0.08 + rnd.nextDouble() * 0.35) * 255).round(),
        );
      canvas.drawCircle(
        Offset(rnd.nextDouble() * size.width, rnd.nextDouble() * size.height),
        0.5 + rnd.nextDouble() * 1.1,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
