import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/servicios_mock.dart';
import '../../models/servicio.dart';
import 'busqueda_invitado.dart';
import 'footer_invitado.dart';
import 'hero_presentacion.dart';
import 'navbar_invitado.dart';
import 'secciones_servicios.dart';

/// Vista HomeGuest (InicioInvitado.jsx): navbar fija + hero + buscador
/// + recientes + destacados + footer.
class HomeGuestScreen extends StatefulWidget {
  const HomeGuestScreen({super.key});

  @override
  State<HomeGuestScreen> createState() => _HomeGuestScreenState();
}

class _HomeGuestScreenState extends State<HomeGuestScreen> {
  final _scroll = ScrollController();
  final _keys = {
    'inicio': GlobalKey(),
    'buscar': GlobalKey(),
    'mejor-calificados': GlobalKey(),
    'soporte': GlobalKey(),
  };
  bool _menuAbierto = false;

  // (backend): reemplazar por GET /api/services
  final List<Servicio> _servicios = serviciosMock;

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

  void _login() => Navigator.of(context).pushNamed('/login');

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= Breakpoints.tablet;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          Column(
            children: [
              NavbarInvitado(
                movil: movil,
                menuAbierto: _menuAbierto,
                onToggleMenu: () => setState(() => _menuAbierto = !_menuAbierto),
                onAncla: _irA,
                onLogin: _login,
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
                          onPublicar: _login,
                        ),
                      ),
                      KeyedSubtree(
                        key: _keys['buscar'],
                        child: BusquedaInvitado(
                          servicios: _servicios,
                          onTapServicio: (_) => _login(),
                        ),
                      ),
                      SeccionRecientes(
                        servicios: _servicios,
                        onTapServicio: (_) => _login(),
                      ),
                      KeyedSubtree(
                        key: _keys['mejor-calificados'],
                        child: SeccionDestacados(
                          servicios: _servicios,
                          onTapServicio: (_) => _login(),
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
    );
  }
}
