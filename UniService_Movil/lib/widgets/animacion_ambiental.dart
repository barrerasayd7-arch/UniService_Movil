// Archivo: animacion_ambiental.dart
// Responsabilidad: activar o congelar animaciones de fondo según dispositivo y
//   preferencias de accesibilidad, sin repintar el resto de la pantalla.
// Se usa desde: pantallas de login/registro que montan cosmos o iconos flotantes.
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

  /// 600 px de lado menor: separa celulares (congelados) de tablet/escritorio/web.
  /// Las pantallas pueden consultarlo para no construir adornos que no se mueven.
  static bool activa(BuildContext context) =>
      !MediaQuery.disableAnimationsOf(context) &&
      MediaQuery.sizeOf(context).shortestSide >= 600;

  @override
  Widget build(BuildContext context) {
    // TickerMode detiene los AnimationController hijos; RepaintBoundary aísla el repintado.
    return RepaintBoundary(
      child: TickerMode(enabled: activa(context), child: child),
    );
  }
}
