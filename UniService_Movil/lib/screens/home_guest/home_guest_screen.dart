// Archivo: home_guest_screen.dart
// Responsabilidad: inicio público con hero, explorador y pie; el detalle se ve
//   sin sesión, pero el contacto exige iniciar sesión.
// Se usa desde: main.dart como ruta '/home-guest'.

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/servicio.dart';
import '../../widgets/explorador_servicios.dart';
import 'footer_invitado.dart';
import 'hero_presentacion.dart';
import 'navbar_invitado.dart';

/// Inicio para invitados: portada + explorador de servicios + pie.
/// Tocar un servicio abre su detalle (sin el contacto, que pide sesión).
class HomeGuestScreen extends StatefulWidget {
  const HomeGuestScreen({super.key});

  @override
  State<HomeGuestScreen> createState() => _HomeGuestScreenState();
}

class _HomeGuestScreenState extends State<HomeGuestScreen> {
  final _scroll = ScrollController();

  // Anclas del scroll: hero, explorador y pie.
  final _keys = {
    'inicio': GlobalKey(),
    'buscar': GlobalKey(),
    'soporte': GlobalKey(),
  };
  bool _menuAbierto = false;

  final _explorador = GlobalKey<ExploradorServiciosState>();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _irA(String ancla) {
    setState(() => _menuAbierto = false);
    // "Top destacados" está dentro del explorador.
    if (ancla == 'mejor-calificados') ancla = 'buscar';
    final ctx = _keys[ancla]?.currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOut,
    );
  }

  void _login() => Navigator.of(context).pushNamed('/login');

  @override
  Widget build(BuildContext context) {
    // En tablet y móvil el navbar usa el menú desplegable.
    final movil = MediaQuery.of(context).size.width <= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: AppColors.bg,
      // SafeArea: la barra superior no queda bajo la hora/batería del celular.
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Column(
              children: [
                NavbarInvitado(
                  movil: movil,
                  menuAbierto: _menuAbierto,
                  onToggleMenu: () =>
                      setState(() => _menuAbierto = !_menuAbierto),
                  onAncla: _irA,
                  onLogin: _login,
                ),
                // El explorador se recarga al tirar hacia abajo, igual que en el home propio.
                Expanded(
                  child: RefreshIndicator(
                    color: AppColors.teal,
                    backgroundColor: AppColors.card,
                    onRefresh: () async =>
                        _explorador.currentState?.recargar(),
                    child: SingleChildScrollView(
                    controller: _scroll,
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        KeyedSubtree(
                          key: _keys['inicio'],
                          child: HeroPresentacion(
                            onExplorar: () => _irA('buscar'),
                            onPublicar: _login,
                          ),
                        ),
                        KeyedSubtree(
                          key: _keys['buscar'],
                          child: ExploradorServicios(
                            key: _explorador,
                            onTapServicio: (Servicio s) => Navigator.of(
                              context,
                            ).pushNamed('/servicio', arguments: s),
                            encabezado: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Explora servicios',
                                  style: AppText.serif(30, height: 1.15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Mira los detalles; inicia sesión para contactar a quien los ofrece.',
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
                          key: _keys['soporte'],
                          child: FooterInvitado(onAncla: _irA, onLogin: _login),
                        ),
                      ],
                    ),
                  ),
                  ),
                ),
              ],
            ),
            if (movil && _menuAbierto)
              Positioned(
                top: 62,
                right: 16,
                child: MenuMovilInvitado(onAncla: _irA, onLogin: _login),
              ),
          ],
        ),
      ),
    );
  }
}
