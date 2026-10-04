import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Equivalente a Components/StarRating.jsx: 5 estrellas con relleno parcial.
class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color color;
  final double gap;

  const StarRating({
    super.key,
    this.rating = 0,
    this.size = 18,
    this.color = AppColors.estrella,
    this.gap = 2,
  });

  @override
  Widget build(BuildContext context) {
    final safe = rating.clamp(0.0, 5.0).toDouble();
    return Semantics(
      label: '${safe.toStringAsFixed(1)} de 5 estrellas',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(5, (i) {
          final fill = (safe - i).clamp(0.0, 1.0).toDouble();
          return Padding(
            padding: EdgeInsets.only(right: i < 4 ? gap : 0),
            child: CustomPaint(
              size: Size(size, size),
              painter: _StarPainter(fill, color),
            ),
          );
        }),
      ),
    );
  }
}

class _StarPainter extends CustomPainter {
  final double fill;
  final Color color;
  _StarPainter(this.fill, this.color);

  // Misma forma que el path SVG original (viewBox 20x20).
  static Path _buildStar() {
    final p = Path()
      ..moveTo(10, 1)
      ..lineTo(12.39, 5.84)
      ..lineTo(17.73, 6.62)
      ..lineTo(13.86, 10.39)
      ..lineTo(14.77, 15.71)
      ..lineTo(10, 13.27)
      ..lineTo(5.23, 15.71)
      ..lineTo(6.14, 10.39)
      ..lineTo(2.27, 6.62)
      ..lineTo(7.61, 5.84)
      ..close();
    return p;
  }

  static final Path _star = _buildStar();

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 20;
    canvas.save();
    canvas.scale(scale, scale);

    // Estrella de fondo (gris)
    canvas.drawPath(_star, Paint()..color = const Color(0xFFD1D5DB));

    // Estrella rellena, recortada según la fracción
    if (fill > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, 20 * fill, 20));
      canvas.drawPath(_star, Paint()..color = color);
      canvas.restore();
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _StarPainter old) =>
      old.fill != fill || old.color != color;
}
