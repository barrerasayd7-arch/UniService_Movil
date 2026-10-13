import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/servicios_mock.dart';
import '../../models/servicio.dart';
import '../home_guest/hero_presentacion.dart';
import '../home_guest/secciones_servicios.dart';
import 'botones_flotantes.dart';
import 'busqueda_home.dart';
import 'footer_home.dart';
import 'navbar_home.dart';
import 'tarjeta_publicar.dart';

/// Vista Home del usuario autenticado (Inicio.jsx):
/// navbar + hero + buscador + recientes + destacados + publicar + footer,
/// más los botones flotantes de chat y notificaciones.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _scroll = ScrollController();
  final _keys = {
    'inicio': GlobalKey(),
    'buscar': GlobalKey(),
    'mejor-calificados': GlobalKey(),
    'publicar': GlobalKey(),
    'soporte': GlobalKey(),
  };

  bool _menuAbierto = false;
  bool _scrolled = false;


  final String _nombreUsuario = 'Usuario';

  final List<Servicio> _servicios = serviciosMock;

  @override
  void initState() {
    super.initState();
    // Si llegamos desde el perfil con un destino (p. ej. 'publicar'), ir allí
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is! String) return;
      if (arg == 'solicitudes') {
        _proximamente('Mis solicitudes');
      } else if (arg == 'mis-servicios') {
        _proximamente('Mis servicios');
      } else {
        _irA(arg);
      }
    });
    _scroll.addListener(() {
      final s = _scroll.offset > 20;
      if (s != _scrolled) setState(() => _scrolled = s);
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _irA(String ancla) {
    setState(() => _menuAbierto = false);
    final ctx = _keys[ancla]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  /// Aviso para las vistas que todavía no están portadas a Flutter.
  void _proximamente(String que) {
    setState(() => _menuAbierto = false);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('$que: próxima vista por implementar'),
          backgroundColor: AppColors.card,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _abrirServicio(Servicio s) {
    Navigator.of(context).pushNamed('/servicio', arguments: s);
  }

  void _irAPerfil() {
    setState(() => _menuAbierto = false);
    Navigator.of(context).pushNamed('/perfil');
  }

  void _cerrarSesion() {
    
    Navigator.of(context).pushNamedAndRemoveUntil('/home-guest', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // La barra con todos los botones no cabe en pantallas medianas
    final movil = MediaQuery.of(context).size.width <= 1100;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              NavbarHome(
                movil: movil,
                menuAbierto: _menuAbierto,
                scrolled: _scrolled,
                nombreUsuario: _nombreUsuario,
                onToggleMenu: () => setState(() => _menuAbierto = !_menuAbierto),
                onAncla: _irA,
                onSolicitudes: () => _proximamente('Mis solicitudes'),
                onPerfil: _irAPerfil,
                onCerrarSesion: _cerrarSesion,
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  child: Column(
                    children: [
                      KeyedSubtree(
                        key: _keys['inicio'],
                        child: HeroPresentacion(
                          onExplorar: () => _irA('buscar'),
                          onPublicar: () => _irA('publicar'),
                        ),
                      ),
                      KeyedSubtree(
                        key: _keys['buscar'],
                        child: BusquedaHome(
                          servicios: _servicios,
                          onTapServicio: _abrirServicio,
                        ),
                      ),
                      SeccionRecientes(
                        servicios: _servicios,
                        onTapServicio: _abrirServicio,
                      ),
                      KeyedSubtree(
                        key: _keys['mejor-calificados'],
                        child: SeccionDestacados(
                          servicios: _servicios,
                          onTapServicio: _abrirServicio,
                        ),
                      ),
                      KeyedSubtree(
                        key: _keys['publicar'],
                        child: TarjetaPublicar(
                          onAbrir: () => _proximamente('Publicar servicio'),
                        ),
                      ),
                      KeyedSubtree(
                        key: _keys['soporte'],
                        child: FooterHome(
                          onAncla: _irA,
                          onPerfil: _irAPerfil,
                          onSolicitudes: () => _proximamente('Mis solicitudes'),
                          onProximamente: () => _proximamente('Esta sección'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (movil && _menuAbierto)
            Positioned(
              top: 62,
              right: 16,
              child: MenuMovilHome(
                nombreUsuario: _nombreUsuario,
                onAncla: _irA,
                onSolicitudes: () => _proximamente('Mis solicitudes'),
                onPerfil: _irAPerfil,
                onCerrarSesion: _cerrarSesion,
              ),
            ),

          BotonesFlotantes(onChat: () => _proximamente('Chat')),
        ],
      ),
    );
  }
}
