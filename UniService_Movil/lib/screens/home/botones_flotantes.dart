// Archivo: botones_flotantes.dart
// Responsabilidad: botones flotantes de chat y notificaciones del home autenticado,
//   con avisos reales y lectura persistida por cuenta en este dispositivo.
// Se usa desde: home_screen.dart, dentro de su Stack.

import 'dart:async';
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/auth_repository.dart';
import '../../data/chat_repository.dart';
import '../../data/notificaciones_controller.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/auth_user.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../chat/chat_session.dart';

/// Botón de chat + campana de notificaciones (Notificaciones.jsx).
/// Colócalo dentro de un Stack: se ancla abajo a la derecha.
/// Ambos contadores provienen de actividad real de la cuenta.
class BotonesFlotantes extends StatefulWidget {
  final VoidCallback onChat;
  final NotificacionesController? controlador;
  final ValueListenable<AuthUser?>? sesion;
  const BotonesFlotantes({
    super.key,
    required this.onChat,
    this.controlador,
    this.sesion,
  });

  @override
  State<BotonesFlotantes> createState() => _BotonesFlotantesState();
}

class _BotonesFlotantesState extends State<BotonesFlotantes>
    with WidgetsBindingObserver, ChatVisible<BotonesFlotantes> {
  late final _control = widget.controlador ?? NotificacionesController();
  late final _sesion = widget.sesion ?? AuthRepository.instance.usuario;
  StreamSubscription<int?>? _chat;
  Timer? _debounce;
  int? _usuario;
  bool _abierto = false;

  @override
  void initState() {
    super.initState();
    iniciarVisibilidad();
    _control.addListener(_cambio);
    _sesion.addListener(_cuenta);
    SolicitudesRepository.instance.cambios.addListener(_actualizar);
    _chat = ChatRepository.instance.cambios.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _actualizar);
    });
    _cuenta();
  }

  void _cuenta() {
    final id = _sesion.value?.id;
    if (id != _usuario) {
      _usuario = id;
      _abierto = false;
    }
    _control.cambiarUsuario(id);
  }

  void _cambio() {
    if (mounted) setState(() {});
  }

  void _actualizar() {
    if (chatVisible) _control.actualizar();
  }

  @override
  void refrescarChat() => _actualizar();
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observarRuta();
  }

  Future<void> _abrirAviso(Notificacion n) async {
    final sesion = _sesion.value;
    await _control.leer(n);
    if (!mounted || sesion != _sesion.value) return;
    setState(() => _abierto = false);
    switch (n.destino) {
      case 'solicitudes':
        Navigator.of(context).pushNamed('/solicitudes', arguments: n.argumento);
      case 'mis-servicios':
        Navigator.of(context).pushNamed('/mis-servicios');
      case 'servicio':
        Navigator.of(context).pushNamed('/servicio', arguments: n.argumento);
    }
  }

  @override
  void dispose() {
    terminarVisibilidad();
    _debounce?.cancel();
    _chat?.cancel();
    _sesion.removeListener(_cuenta);
    SolicitudesRepository.instance.cambios.removeListener(_actualizar);
    _control.removeListener(_cambio);
    if (widget.controlador == null) _control.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mismo tamaño para ambos accesos, más compacto que el chat anterior (66).
    const ladoBoton = 56.0;
    const ladoIcono = 24.0;

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
            _Panel(control: _control, onLeer: _abrirAviso),
            const SizedBox(height: 12),
          ],
          ValueListenableBuilder<int>(
            valueListenable: mensajesNoLeidos,
            builder: (_, total, _) => Semantics(
              button: true,
              label: 'Mis chats, $total mensajes sin leer',
              child: _CircleButton(
                size: ladoBoton,
                icono: Icons.chat_bubble,
                iconSize: ladoIcono,
                badge: total,
                onTap: widget.onChat,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Semantics(
            button: true,
            label: 'Notificaciones, ${_control.noLeidas} sin leer',
            child: _CircleButton(
              size: ladoBoton,
              icono: Icons.notifications,
              iconSize: ladoIcono,
              badge: _control.noLeidas,
              onTap: () {
                setState(() => _abierto = !_abierto);
                if (_abierto) _control.actualizar();
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Burbuja circular reutilizable: crece al hover y muestra una insignia
/// cuando [badge] es mayor que cero.
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
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: const Color(0xFF093B38),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '$badge',
                      style: AppText.poppins(
                        11,
                        weight: FontWeight.w700,
                        color: Colors.white,
                      ),
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

/// Listado desplegable de notificaciones; avisa al padre cuándo vaciar
/// la lista o marcar una entrada como leída.
class _Panel extends StatelessWidget {
  final NotificacionesController control;
  final ValueChanged<Notificacion> onLeer;
  const _Panel({required this.control, required this.onLeer});

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final notifs = control.avisos;
    final noLeidas = control.noLeidas;
    return Material(
      color: Colors.transparent,
      child: Container(
        width: (ancho - 60).clamp(0.0, 340.0).toDouble(),
        constraints: BoxConstraints(
          maxHeight:
              (MediaQuery.of(context).size.height -
                      MediaQuery.paddingOf(context).vertical -
                      210)
                  .clamp(100.0, 500.0),
        ),
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
                    onPressed: notifs.isEmpty ? null : control.vaciar,
                    tooltip: 'Descartar avisos de este dispositivo',
                    icon: const Icon(
                      Icons.delete_outline,
                      size: 18,
                      color: AppColors.texto2,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: Colors.white.withAlpha(20)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Wrap(
                alignment: WrapAlignment.end,
                children: [
                  TextButton(
                    onPressed: noLeidas == 0 ? null : control.leerTodas,
                    child: const Text('Marcar todas leídas'),
                  ),
                  IconButton(
                    onPressed: control.cargando ? null : control.actualizar,
                    tooltip: 'Actualizar notificaciones',
                    icon: const Icon(Icons.refresh, size: 20),
                  ),
                ],
              ),
            ),
            if (control.cargando) const LinearProgressIndicator(minHeight: 2),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                padding: const EdgeInsets.all(10),
                children: [
                  if (control.error != null || control.errorGuardado != null)
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Text(
                        control.error ?? control.errorGuardado!,
                        style: AppText.poppins(13, color: AppColors.errorTexto),
                      ),
                    ),
                  if (notifs.isEmpty &&
                      !control.cargando &&
                      control.error == null)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No tienes notificaciones pendientes',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (control.cargando && notifs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Cargando notificaciones...',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  for (final n in notifs)
                    Semantics(
                      button: true,
                      child: InkWell(
                        onTap: () => onLeer(n),
                        child: Opacity(
                          opacity: control.leida(n) ? 0.65 : 1,
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(8),
                              border: Border(
                                left: BorderSide(
                                  color: control.leida(n)
                                      ? AppColors.texto2
                                      : AppColors.teal,
                                  width: 3,
                                ),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n.texto,
                                  style: AppText.poppins(
                                    12.8,
                                    color: AppColors.texto,
                                    height: 1.4,
                                  ),
                                ),
                                if (n.fecha != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    MaterialLocalizations.of(
                                      context,
                                    ).formatShortDate(n.fecha!.toLocal()),
                                    style: AppText.poppins(
                                      11,
                                      color: AppColors.texto2,
                                    ),
                                  ),
                                ],
                              ],
                            ),
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
