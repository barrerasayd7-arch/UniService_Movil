import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/chat_realtime.dart';
import '../../data/chat_repository.dart';

/// Contador real compartido con el botón del inicio. Se borra al cambiar de cuenta.
final mensajesNoLeidos = ValueNotifier<int>(0);
final chatRouteObserver = RouteObserver<ModalRoute<void>>();

/// Vincula el tiempo real al ciclo de vida de la aplicación y la cuenta.
class ChatSession extends StatefulWidget {
  const ChatSession({super.key, required this.child});
  final Widget child;
  @override
  State<ChatSession> createState() => _ChatSessionState();
}

class _ChatSessionState extends State<ChatSession> with WidgetsBindingObserver {
  Timer? _timer;
  Timer? _debounce;
  StreamSubscription<int?>? _cambios;
  int? _usuario;
  int _generacion = 0;
  int? _consultando;
  DateTime? _ultimaActividad;
  bool _enPrimerPlano = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    AuthRepository.instance.usuario.addListener(_sincronizar);
    _cambios = ChatRepository.instance.cambios.listen((_) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 250), _actualizar);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _sincronizar();
    });
  }

  void _sincronizar() {
    final id = AuthRepository.instance.usuario.value?.id;
    if (id != _usuario || !_enPrimerPlano) {
      _generacion++;
      ChatRealtime.instance.desconectar();
      _timer?.cancel();
      _timer = null;
      _ultimaActividad = null;
      if (id != _usuario) mensajesNoLeidos.value = 0;
      _usuario = id;
    }
    if (id == null || !_enPrimerPlano) return;
    _timer ??= Timer.periodic(
      const Duration(seconds: 20),
      (_) => _actualizar(),
    );
    _actualizar();
  }

  Future<void> _actualizar() async {
    if (!mounted ||
        _usuario == null ||
        !_enPrimerPlano ||
        _consultando == _generacion) {
      return;
    }
    final generacion = _generacion;
    _consultando = generacion;
    unawaited(ChatRealtime.instance.conectar());
    try {
      final total = await ChatRepository.instance.noLeidos();
      if (!mounted || generacion != _generacion) return;
      mensajesNoLeidos.value = total;
      final ahora = DateTime.now();
      if (_ultimaActividad == null ||
          ahora.difference(_ultimaActividad!) >= const Duration(seconds: 60)) {
        await ChatRepository.instance.actividad();
        if (mounted && generacion == _generacion) _ultimaActividad = ahora;
      }
    } on ApiException {
      // No sustituir un contador real por uno inventado ante un fallo de red.
      // Los 401/suspensiones ya los gestiona ApiClient.
    } finally {
      if (_consultando == generacion) _consultando = null;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _enPrimerPlano = state == AppLifecycleState.resumed;
    _sincronizar();
  }

  @override
  void dispose() {
    _generacion++;
    _timer?.cancel();
    _debounce?.cancel();
    _cambios?.cancel();
    AuthRepository.instance.usuario.removeListener(_sincronizar);
    WidgetsBinding.instance.removeObserver(this);
    ChatRealtime.instance.desconectar();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Refresca sólo la ruta visible. Volver desde un perfil o reanudar la app
/// sincroniza inmediatamente; el timer cubre cortes de SignalR.
mixin ChatVisible<T extends StatefulWidget> on State<T>
    implements WidgetsBindingObserver, RouteAware {
  Timer? _refresco;
  ModalRoute<void>? _ruta;
  bool _primerPlano = true;
  bool get chatVisible => mounted && _primerPlano && (_ruta?.isCurrent ?? true);
  void refrescarChat();
  void cambioVisibilidad(bool visible) {}

  void iniciarVisibilidad() {
    WidgetsBinding.instance.addObserver(this);
    _refresco = Timer.periodic(const Duration(seconds: 10), (_) {
      if (chatVisible) refrescarChat();
    });
  }

  void observarRuta() {
    final ruta = ModalRoute.of(context);
    if (ruta == _ruta) return;
    chatRouteObserver.unsubscribe(this);
    _ruta = ruta;
    if (ruta != null) chatRouteObserver.subscribe(this, ruta);
  }

  void terminarVisibilidad() {
    _refresco?.cancel();
    chatRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
  }

  @override
  void didPush() => cambioVisibilidad(chatVisible);
  @override
  void didPop() => cambioVisibilidad(false);
  @override
  void didPushNext() => cambioVisibilidad(false);
  @override
  void didPopNext() {
    cambioVisibilidad(chatVisible);
    if (chatVisible) refrescarChat();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _primerPlano = state == AppLifecycleState.resumed;
    cambioVisibilidad(chatVisible);
    if (chatVisible) refrescarChat();
  }

  // WidgetsBindingObserver aporta implementaciones por defecto a los estados
  // que usan este mixin (ver declaraciones de las pantallas).
}
