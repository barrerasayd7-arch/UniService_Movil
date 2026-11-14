import 'package:flutter/material.dart';
import '../core/app_colors.dart';

/// Relieve al pasar el cursor y una pulsación breve antes de abrir un servicio.
class TarjetaInteractiva extends StatefulWidget {
  const TarjetaInteractiva({
    super.key,
    required this.child,
    required this.label,
    required this.onTap,
  });

  final Widget child;
  final String label;
  final VoidCallback onTap;

  @override
  State<TarjetaInteractiva> createState() => _TarjetaInteractivaState();
}

class _TarjetaInteractivaState extends State<TarjetaInteractiva>
    with SingleTickerProviderStateMixin {
  late final _animacion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
    reverseDuration: const Duration(milliseconds: 110),
  );
  bool _hover = false;
  bool _presionada = false;
  bool _abriendo = false;

  void _actualizar() {
    if (_abriendo) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _animacion.value = 0;
    } else if (_hover || _presionada) {
      _animacion.forward();
    } else {
      _animacion.reverse();
    }
  }

  Future<void> _abrir() async {
    if (_abriendo) return;
    _abriendo = true;
    try {
      if (!MediaQuery.disableAnimationsOf(context)) {
        setState(() => _presionada = true);
        await _animacion.forward().orCancel;
        await _animacion.reverse().orCancel;
      }
      if (mounted) widget.onTap();
    } on TickerCanceled {
      // La lista o la pantalla pudo desmontarse durante la pulsación.
    } finally {
      _abriendo = false;
      if (mounted) setState(() => _presionada = false);
    }
  }

  @override
  void dispose() {
    _animacion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AppColors.of(context);
    return Semantics(
      button: true,
      label: widget.label,
      excludeSemantics: true,
      onTap: _abrir,
      child: AnimatedBuilder(
        animation: _animacion,
        child: widget.child,
        builder: (context, child) {
          final t = Curves.easeOutCubic.transform(_animacion.value);
          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..translateByDouble(0, -4 * t, 0, 1)
              ..rotateX(0.012 * t)
              ..rotateY(-0.012 * t)
              ..scaleByDouble(
                1 - (_presionada ? .018 * t : 0),
                1 - (_presionada ? .018 * t : 0),
                1,
                1,
              ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: p.teal.withValues(alpha: .15 * t),
                    blurRadius: 18 * t,
                    offset: Offset(0, 6 * t),
                  ),
                ],
              ),
              child: Material(
                color: Color.lerp(p.card, p.cardHover, t),
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: Color.lerp(p.borde, p.teal, t)!),
                ),
                child: InkWell(
                  onTap: _abrir,
                  onHover: (value) {
                    _hover = value;
                    _actualizar();
                  },
                  onHighlightChanged: (value) {
                    _presionada = value;
                    _actualizar();
                  },
                  splashColor: p.teal.withValues(alpha: .12),
                  highlightColor: p.teal.withValues(alpha: .06),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
