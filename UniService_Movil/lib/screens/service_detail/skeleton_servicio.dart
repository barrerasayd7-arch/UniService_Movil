import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Esqueleto de carga (`Cargando.jsx` / `.skeleton`): barras con brillo animado.
class SkeletonServicio extends StatefulWidget {
  const SkeletonServicio({super.key});

  @override
  State<SkeletonServicio> createState() => _SkeletonServicioState();
}

class _SkeletonServicioState extends State<SkeletonServicio>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Widget _barra(double alto, double fraccion) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // background-position: 200% -> -200% sobre un degradado de 200% de ancho
        final dx = 2 - 4 * _c.value;
        return FractionallySizedBox(
          widthFactor: fraccion,
          alignment: Alignment.centerLeft,
          child: Container(
            height: alto,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              gradient: LinearGradient(
                begin: Alignment(dx - 1, 0),
                end: Alignment(dx + 1, 0),
                stops: const [0.25, 0.5, 0.75],
                colors: const [AppColors.bg2, AppColors.bg3, AppColors.bg2],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _barra(40, 0.6),
          _barra(20, 0.9),
          _barra(20, 0.4),
        ],
      ),
    );
  }
}
