// Archivo: home_screen.dart
// Responsabilidad: orquesta el home autenticado (navbar, explorador, publicar,
//   pie y botones flotantes) y resuelve anclas, refresco y argumentos de ruta.
// Se usa desde: main.dart como ruta '/home'.

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/auth_repository.dart';
import '../../models/servicio.dart';
import '../../core/app_text.dart';
import '../../widgets/explorador_servicios.dart';
import 'botones_flotantes.dart';
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

  // Claves de sección: permiten desplazarse sin depender de offsets fijos.
  final _keys = {
    'inicio': GlobalKey(),
    'publicar': GlobalKey(),
    'soporte': GlobalKey(),
  };

  bool _menuAbierto = false;
  bool _scrolled = false;

  // Sólo el primer nombre: se usa en el saludo y en el navbar.
  String get _nombreUsuario {
    final nombre = AuthRepository.instance.usuario.value?.nombre.trim() ?? '';
    return nombre.isEmpty ? 'Usuario' : nombre.split(' ').first;
  }

  final _explorador = GlobalKey<ExploradorServiciosState>();

  @override
  void initState() {
    super.initState();
    // Si llegamos desde el perfil con un destino (p. ej. 'publicar'), ir allí
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final arg = ModalRoute.of(context)?.settings.arguments;
      if (arg is! String) return;
      if (arg == 'solicitudes') {
        _abrir('/solicitudes');
      } else if (arg == 'mis-servicios') {
        _abrir('/mis-servicios');
      } else if (arg == 'publicar') {
        _abrir('/publicar');
      } else {
        _irA(arg);
      }
    });
    // Activa la sombra del navbar en cuanto el usuario abandona el tope.
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
    // Buscar y "Top destacados" viven ahora en el explorador del inicio.
    if (ancla == 'buscar' || ancla == 'mejor-calificados') ancla = 'inicio';
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

  // Cierra el menú móvil antes de navegar para que no quede superpuesto.
  void _abrir(String ruta) {
    setState(() => _menuAbierto = false);
    Navigator.of(context).pushNamed(ruta);
  }

  void _abrirServicio(Servicio s) {
    Navigator.of(context).pushNamed('/servicio', arguments: s);
  }

  /// Entrada al panel (sólo cuentas admin): pide la contraseña de administrador.
  VoidCallback? get _panelAdmin =>
      (AuthRepository.instance.usuario.value?.esAdmin ?? false)
      ? () => Navigator.of(context).pushNamed('/admin')
      : null;

  void _irAPerfil() {
    setState(() => _menuAbierto = false);
    Navigator.of(context).pushNamed('/perfil');
  }

  // Al cerrar sesión se reemplaza toda la pila por el inicio de invitado.
  Future<void> _cerrarSesion() async {
    await AuthRepository.instance.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/home-guest', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    // La barra con todos los botones no cabe en pantallas medianas
    final movil = MediaQuery.of(context).size.width <= 1100;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // SafeArea: la barra superior no queda bajo la hora/batería del celular.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                NavbarHome(
                  movil: movil,
                  menuAbierto: _menuAbierto,
                  scrolled: _scrolled,
                  nombreUsuario: _nombreUsuario,
                  onToggleMenu: () =>
                      setState(() => _menuAbierto = !_menuAbierto),
                  onAncla: _irA,
                  onSolicitudes: () => _abrir('/solicitudes'),
                  onPerfil: _irAPerfil,
                  onCerrarSesion: _cerrarSesion,
                  onPanelAdmin: _panelAdmin,
                ),
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.teal,
                    backgroundColor: AppColors.card,
                    onRefresh: () async => _explorador.currentState?.recargar(),
                    child: SingleChildScrollView(
                      controller: _scroll,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        children: [
                          // Lo primero: buscar. (La portada de marketing queda para invitados.)
                          KeyedSubtree(
                            key: _keys['inicio'],
                            child: ExploradorServicios(
                              key: _explorador,
                              onTapServicio: _abrirServicio,
                              encabezado: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Hola, $_nombreUsuario',
                                    style: AppText.serif(30, height: 1.15),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '¿Qué necesitas hoy?',
                                    style: AppText.poppins(
                                      15,
                                      color: AppColors.texto2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          KeyedSubtree(
                            key: _keys['publicar'],
                            child: TarjetaPublicar(
                              onAbrir: () => _abrir('/publicar'),
                            ),
                          ),
                          KeyedSubtree(
                            key: _keys['soporte'],
                            child: FooterHome(
                              onAncla: _irA,
                              onPerfil: _irAPerfil,
                              onSolicitudes: () => _abrir('/solicitudes'),
                              onProximamente: () =>
                                  _proximamente('Esta sección'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // El desplegable flota bajo el navbar y se cierra al elegir una opción.
            if (movil && _menuAbierto)
              Positioned(
                top: 62,
                right: 16,
                child: MenuMovilHome(
                  nombreUsuario: _nombreUsuario,
                  onAncla: _irA,
                  onSolicitudes: () => _abrir('/solicitudes'),
                  onPerfil: _irAPerfil,
                  onCerrarSesion: _cerrarSesion,
                  onPanelAdmin: _panelAdmin,
                ),
              ),

            // Chat y notificaciones se superponen al scroll en la esquina inferior.
            BotonesFlotantes(onChat: () => _proximamente('Chat')),
          ],
        ),
      ),
    );
  }
}
