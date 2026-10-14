import 'package:flutter/widgets.dart';

/// Envuelve un fondo o adorno animado en bucle (cosmos, tesseract, iconos flotantes…).
///
/// - En celulares, o con "reducir movimiento" activado en el sistema, congela la
///   animación en su primer cuadro: se ve igual, pero la pantalla deja de
///   redibujarse 60 veces por segundo (fluidez y batería).
/// - En tablet, escritorio y web se anima como en la página web.
/// - Siempre aísla su repintado para no arrastrar al resto de la pantalla.
class AnimacionAmbiental extends StatelessWidget {
  final Widget child;
  const AnimacionAmbiental({super.key, required this.child});

  static bool activa(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) &&
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: TickerMode(enabled: activa(context), child: child),
    );
  }
}
