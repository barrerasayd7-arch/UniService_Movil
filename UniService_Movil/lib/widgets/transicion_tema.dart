import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../data/tema_controller.dart';

/// Cubre la pantalla antes de cambiar los colores y revela el nuevo tema.
abstract final class TransicionTema {
  static bool _enCurso = false;

  static Future<bool?> cambiar(BuildContext context) async {
    if (_enCurso) return null;
    final tema = TemaController.instance;
    if (MediaQuery.disableAnimationsOf(context)) return tema.alternar();
    _enCurso = true;
    Future<bool>? guardado;
    final destinoOscuro = !tema.oscuro;
    try {
      await showGeneralDialog<void>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 320),
        pageBuilder: (context, _, _) => _PantallaCambioTema(
          oscuro: destinoOscuro,
          onCambiar: () => guardado = tema.alternar(),
        ),
        transitionBuilder: (context, animacion, _, child) => SlideTransition(
          position:
              Tween<Offset>(
                begin: Offset(destinoOscuro ? -1 : 1, 0),
                end: Offset.zero,
              ).animate(
                CurvedAnimation(
                  parent: animacion,
                  curve: Curves.easeInOutCubic,
                ),
              ),
          child: child,
        ),
      );
    } finally {
      _enCurso = false;
    }
    return guardado == null ? null : await guardado!;
  }
}

class _PantallaCambioTema extends StatefulWidget {
  const _PantallaCambioTema({required this.oscuro, required this.onCambiar});
  final bool oscuro;
  final VoidCallback onCambiar;

  @override
  State<_PantallaCambioTema> createState() => _PantallaCambioTemaState();
}

class _PantallaCambioTemaState extends State<_PantallaCambioTema>
    with SingleTickerProviderStateMixin {
  late final _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  );
  bool _aplicado = false;

  @override
  void initState() {
    super.initState();
    _animacion.addListener(() {
      // A los 440 ms la entrada de 320 ms ya ha cubierto la pantalla.
      if (!_aplicado && _animacion.value >= .4) {
        _aplicado = true;
        widget.onCambiar();
      }
    });
    _animacion.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        Navigator.of(context).pop();
      }
    });
    _animacion.forward();
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppPalette(oscuro: widget.oscuro);
    return PopScope(
      canPop: false,
      child: Material(
        color: p.bg,
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [p.bg, p.bg3, p.bg],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Semantics(
                  liveRegion: true,
                  label:
                      'Cambiando a tema ${widget.oscuro ? 'oscuro' : 'claro'}',
                  excludeSemantics: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: _animacion,
                        builder: (context, _) => SizedBox.square(
                          dimension: 150,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Transform.rotate(
                                angle: _animacion.value * math.pi,
                                child: SizedBox(
                                  width: 140,
                                  height: 140,
                                  child: CircularProgressIndicator(
                                    value: .72,
                                    strokeWidth: 3,
                                    color: p.teal,
                                    backgroundColor: p.amarillo.withValues(
                                      alpha: .25,
                                    ),
                                  ),
                                ),
                              ),
                              Transform.scale(
                                scale:
                                    1 +
                                    .08 * math.sin(_animacion.value * math.pi),
                                child: Container(
                                  padding: const EdgeInsets.all(26),
                                  decoration: BoxDecoration(
                                    color: p.tealDim,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    widget.oscuro
                                        ? Icons.dark_mode_rounded
                                        : Icons.light_mode_rounded,
                                    size: 48,
                                    color: widget.oscuro ? p.teal : p.amarillo,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Cambiando tema',
                        style: AppText.poppins(
                          22,
                          weight: FontWeight.w600,
                          color: p.texto,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Activando modo ${widget.oscuro ? 'oscuro' : 'claro'}',
                        style: AppText.poppins(14, color: p.texto2),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: 160,
                        child: AnimatedBuilder(
                          animation: _animacion,
                          builder: (context, _) => LinearProgressIndicator(
                            value: _animacion.value,
                            minHeight: 3,
                            borderRadius: BorderRadius.circular(4),
                            color: p.teal,
                            backgroundColor: p.borde,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
