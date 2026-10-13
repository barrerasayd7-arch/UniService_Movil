import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

class _Notif {
  final String texto;
  bool leida;
  _Notif(this.texto, {this.leida = false});
}

/// Botón de chat + campana de notificaciones (Notificaciones.jsx).
/// Colócalo dentro de un Stack: se ancla abajo a la derecha.
/// Los datos son de ejemplo; después se conectan a la API.
class BotonesFlotantes extends StatefulWidget {
  final VoidCallback onChat;
  const BotonesFlotantes({super.key, required this.onChat});

  @override
  State<BotonesFlotantes> createState() => _BotonesFlotantesState();
}

class _BotonesFlotantesState extends State<BotonesFlotantes> {
  bool _abierto = false;
  final int _mensajesNoLeidos = 2; 


  final List<_Notif> _notifs = [
    _Notif('Tu solicitud de "Tutoría de Cálculo" fue aceptada.'),
    _Notif('Carlos dejó una reseña en tu servicio.'),
    _Notif('Tu servicio "Diseño de logos" fue aprobado.'),
    _Notif('Bienvenido a UniService.', leida: true),
  ];

  int get _noLeidas => _notifs.where((n) => !n.leida).length;

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final bell = ancho <= 480 ? 42.0 : ancho <= 768 ? 48.0 : ancho <= 1024 ? 55.0 : 60.0;
    final bellIcon = ancho <= 480 ? 18.0 : ancho <= 768 ? 20.0 : ancho <= 1024 ? 22.0 : 24.0;

    // El panel va en la misma columna (encima de los botones) para que
    // reciba los toques; Positioned no pasa hit-test fuera de su Stack.
    return Positioned(
      right: 30,
      bottom: 30,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_abierto) ...[
            _Panel(
              notifs: _notifs,
              noLeidas: _noLeidas,
              onVaciar: () => setState(_notifs.clear),
              onLeer: (n) => setState(() => n.leida = true),
            ),
            const SizedBox(height: 12),
          ],
          _CircleButton(
            size: 66,
            icono: Icons.chat_bubble,
            iconSize: 26,
            badge: _mensajesNoLeidos,
            onTap: widget.onChat,
          ),
          const SizedBox(height: 12),
          _CircleButton(
            size: bell,
            icono: Icons.notifications,
            iconSize: bellIcon,
            badge: _noLeidas,
            onTap: () => setState(() => _abierto = !_abierto),
          ),
        ],
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final double size;
  final IconData icono;
  final double iconSize;
  final int badge;
  final VoidCallback onTap;
  const _CircleButton({
    required this.size,
    required this.icono,
    required this.iconSize,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedScale(
          duration: const Duration(milliseconds: 300),
          scale: hover ? 1.1 : 1,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hover ? AppColors.teal : const Color(0xFF09615E),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(102),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(icono, size: iconSize, color: Colors.white),
              ),
              if (badge > 0)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF093B38), width: 2),
                    ),
                    child: Text(
                      '$badge',
                      style: AppText.poppins(11, weight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  final List<_Notif> notifs;
  final int noLeidas;
  final VoidCallback onVaciar;
  final ValueChanged<_Notif> onLeer;
  const _Panel({
    required this.notifs,
    required this.noLeidas,
    required this.onVaciar,
    required this.onLeer,
  });

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: (ancho - 40).clamp(200.0, 320.0).toDouble(),
        constraints: const BoxConstraints(maxHeight: 500),
        decoration: BoxDecoration(
          color: const Color(0xFF1A2235),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(26)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(128),
              blurRadius: 30,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Notificaciones${noLeidas > 0 ? ' ($noLeidas nuevas)' : ''}',
                      style: AppText.poppins(14.4, weight: FontWeight.w700),
                    ),
                  ),
                  IconButton(
                    onPressed: onVaciar,
                    tooltip: 'Vaciar todas las notificaciones',
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.texto2),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withAlpha(20)),
            Flexible(
              child: notifs.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        'No tienes notificaciones pendientes',
                        textAlign: TextAlign.center,
                        style: AppText.poppins(13, color: AppColors.texto2),
                      ),
                    )
                  : ListView(
                      shrinkWrap: true,
                      padding: const EdgeInsets.all(10),
                      children: [
                        for (final n in notifs)
                          GestureDetector(
                            onTap: n.leida ? null : () => onLeer(n),
                            child: Opacity(
                              opacity: n.leida ? 0.5 : 1,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha(10),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border(
                                    left: BorderSide(
                                      color: n.leida
                                          ? const Color(0xFF4B5563)
                                          : const Color(0xFF4AC7B6),
                                      width: 3,
                                    ),
                                  ),
                                ),
                                child: Text(
                                  n.texto,
                                  style: AppText.poppins(12.8, color: AppColors.texto, height: 1.4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
