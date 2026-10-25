// Archivo: floating_icons.dart
// Responsabilidad: adorno animado de iconos que caen girando y halos que pulsan,
//   dibujado sobre el login.
// Se usa desde: pantalla de login, dentro de AnimacionAmbiental.
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// Port de Components/FloatingIcons.jsx: iconos que caen girando
/// + círculos de brillo que pulsan.
class FloatingIcons extends StatefulWidget {
  const FloatingIcons({super.key});

  @override
  State<FloatingIcons> createState() => _FloatingIconsState();
}

/// Halo circular estático: posición en % del contenedor y duración del pulso.
class _GlowData {
  final double left, top, size, dur;
  const _GlowData(this.left, this.top, this.size, this.dur);
}

/// Icono que cae: posición en %, duración, retraso y tamaño en px.
class _IconData {
  final IconData icon;
  final double left, dur, delay, size;
  const _IconData(this.icon, this.left, this.dur, this.delay, this.size);
}

class _FloatingIconsState extends State<FloatingIcons>
    with SingleTickerProviderStateMixin {
  // Mismo bucle de 1 h que CosmosBackground para que ambos adornos encajen.
  static const int _ciclo = 3600;
  late final AnimationController _c;

  static const _iconos = [
    Icons.menu_book_outlined,
    Icons.edit_outlined,
    Icons.folder_outlined,
    Icons.code,
    Icons.palette_outlined,
    Icons.home_outlined,
    Icons.public,
  ];

  static const _glows = [
    _GlowData(10, 20, 300, 7),
    _GlowData(35, 50, 250, 10),
    _GlowData(5, 70, 200, 5.5),
    _GlowData(50, 30, 180, 13),
    _GlowData(20, 85, 220, 8.5),
  ];

  late final List<_IconData> _items;

  @override
  void initState() {
    super.initState();
    // Semilla fija: la lluvia de iconos es la misma en cada arranque.
    final r = math.Random(21);
    _items = List.generate(6, (i) {
      return _IconData(
        _iconos[r.nextInt(_iconos.length)],
        r.nextDouble() * 68 - 5, // % desde la izquierda
        14 + r.nextDouble() * 6, // segundos
        i * 4.0, // delay
        (1.2 + r.nextDouble() * 0.8) * 16, // tamaño en px
      );
    });
    _c = AnimationController(
      vsync: this,
      duration: const Duration(seconds: _ciclo),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  double _lerp(double a, double b, double t) => a + (b - a) * t;

  /// glowPulse: alternate infinite ease-in-out
  Widget _glow(_GlowData g, double w, double h, double seg) {
    // Onda triangular 0→1→0: ida con una curva, vuelta con otra (alternate).
    var u = (seg / g.dur) % 2;
    if (u > 1) u = 2 - u;
    double opacity, ty, scale;
    if (u <= 0.5) {
      final s = Curves.easeInOut.transform(u / 0.5);
      opacity = _lerp(0.3, 0.5, s);
      ty = _lerp(-0.5, -0.8, s);
      scale = _lerp(0.8, 1.0, s);
    } else {
      final s = Curves.easeInOut.transform((u - 0.5) / 0.5);
      opacity = _lerp(0.5, 0.7, s);
      ty = _lerp(-0.8, -0.2, s);
      scale = _lerp(1.0, 1.2, s);
    }
    return Positioned(
      left: w * g.left / 100 - g.size / 2,
      top: h * g.top / 100 + ty * g.size,
      width: g.size,
      height: g.size,
      child: Opacity(
        opacity: opacity,
        child: Transform.scale(
          scale: scale,
          child: Container(
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0x1F2DD4BF), Colors.transparent],
                stops: [0, 0.7],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// floatDown: cae 110vh girando; opacidad 0 -> 0.4 -> 0
  Widget _icono(_IconData it, double w, double h, double seg) {
    final local = seg - it.delay;
    if (local < 0) return const SizedBox.shrink();
    final p = (local % it.dur) / it.dur;
    // Funde en el 8 % inicial y final del recorrido; en medio queda a 0.4.
    double opacity;
    if (p < 0.08) {
      opacity = 0.4 * (p / 0.08);
    } else if (p > 0.92) {
      opacity = 0.4 * ((1 - p) / 0.08);
    } else {
      opacity = 0.4;
    }
    return Positioned(
      left: w * it.left / 100,
      top: -0.05 * h + p * 1.1 * h,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0).toDouble(),
        child: Transform.rotate(
          angle: p * 2 * math.pi,
          child: Icon(it.icon, size: it.size, color: AppColors.tealBrillante),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // IgnorePointer evita robar toques; ClipRect recorta lo que cae fuera de pantalla.
    return IgnorePointer(
      child: ClipRect(
        child: LayoutBuilder(
          builder: (context, box) {
            return AnimatedBuilder(
              animation: _c,
              builder: (context, _) {
                final seg = _c.value * _ciclo;
                return Stack(
                  children: [
                    for (final g in _glows)
                      _glow(g, box.maxWidth, box.maxHeight, seg),
                    for (final it in _items)
                      _icono(it, box.maxWidth, box.maxHeight, seg),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}
