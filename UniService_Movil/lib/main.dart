import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'data/admin_repository.dart';
import 'data/auth_repository.dart';
import 'screens/admin/admin_acceso_screen.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/home/home_screen.dart';
import 'screens/home_guest/home_guest_screen.dart';
import 'screens/login/auth_widgets.dart';
import 'screens/login/login_screen.dart';
import 'models/servicio.dart';
import 'screens/mis_servicios/mis_servicios_screen.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/publicar/publicar_screen.dart';
import 'screens/service_detail/detail_screen.dart';
import 'screens/solicitudes/solicitudes_screen.dart';
import 'screens/admin/admin_actividad_screen.dart';
import 'screens/admin/admin_categorias_screen.dart';
import 'screens/admin/admin_reportes_screen.dart';
import 'screens/admin/admin_servicios_screen.dart';
import 'screens/admin/admin_usuarios_screen.dart';

final navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Poppins y DM Serif Display van dentro de la app (assets/google_fonts): sin descargas
  // al abrirla, sin parpadeo de fuente y funcionan sin internet.
  GoogleFonts.config.allowRuntimeFetching = false;
  LicenseRegistry.addLicense(() async* {
    for (final fuente in ['Poppins', 'DMSerifDisplay']) {
      final licencia = await rootBundle.loadString(
        'assets/google_fonts/OFL-$fuente.txt',
      );
      yield LicenseEntryWithLineBreaks(['google_fonts'], licencia);
    }
  });

  final auth = AuthRepository.instance;
  await auth.restaurar();

  // Si el servidor rechaza la sesión (vencida o cuenta suspendida), volver al login y avisar.
  auth.onSesionCerrada = (mensaje) {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    nav.pushNamedAndRemoveUntil('/login', (_) => false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = navigatorKey.currentContext;
      if (ctx != null) mostrarNotificacion(ctx, mensaje);
    });
  };

  runApp(UniServiceApp(rutaInicial: auth.haySesion ? '/home' : '/home-guest'));
}

class UniServiceApp extends StatelessWidget {
  final String rutaInicial;
  const UniServiceApp({super.key, required this.rutaInicial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniService',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.bg,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.teal,
          secondary: AppColors.amarillo,
          surface: AppColors.card,
        ),
      ),
      initialRoute: rutaInicial,
      routes: {
        '/login': (_) => const LoginScreen(),
        '/home-guest': (_) => const HomeGuestScreen(),
        '/home': (_) => const HomeScreen(),
        '/perfil': (_) => const ProfileScreen(),
        // Argumento: el Servicio de la tarjeta o el id (int).
        '/servicio': (ctx) {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          return DetailScreen(
            servicio: arg is Servicio ? arg : null,
            idServicio: arg is int ? arg : null,
          );
        },
        '/perfil-externo': (ctx) => ProfileScreen(
          externo: true,
          idUsuario: ModalRoute.of(ctx)?.settings.arguments as int?,
        ),
        // Con un id (int) edita ese servicio; sin argumento publica uno nuevo.
        '/publicar': (ctx) => _conSesion(() {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          return PublicarScreen(idServicio: arg is int ? arg : null);
        }),
        '/mis-servicios': (_) => _conSesion(() => const MisServiciosScreen()),
        // Argumento opcional: 1 abre la pestaña de enviadas.
        '/solicitudes': (ctx) => _conSesion(() {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          return SolicitudesScreen(pestanaInicial: arg is int ? arg : 0);
        }),
        // Panel admin: sin la contraseña de administrador (o vencida) muestra la puerta de acceso.
        '/admin': (_) => _conSesion(
          () => !(AuthRepository.instance.usuario.value?.esAdmin ?? false)
              ? const HomeScreen()
              : AdminRepository.instance.dentroDelPanel
              ? const AdminPanelScreen()
              : const AdminAccesoScreen(),
        ),
        '/admin/usuarios': (_) => _conPanel(() => const AdminUsuariosScreen()),
        '/admin/servicios': (_) =>
            _conPanel(() => const AdminServiciosScreen()),
        '/admin/pendientes': (_) =>
            _conPanel(() => const AdminServiciosScreen(soloPendientes: true)),
        '/admin/reportes': (_) => _conPanel(() => const AdminReportesScreen()),
        '/admin/categorias': (_) =>
            _conPanel(() => const AdminCategoriasScreen()),
        '/admin/actividad': (_) =>
            _conPanel(() => const AdminActividadScreen()),
      },
    );
  }
}

/// Las pantallas de la cuenta llevan al login si no hay sesión.
Widget _conSesion(Widget Function() pantalla) =>
    AuthRepository.instance.haySesion ? pantalla() : const LoginScreen();

/// Las pantallas del panel piden además ser admin y tener la contraseña de administrador vigente.
Widget _conPanel(Widget Function() pantalla) => _conSesion(
  () => !(AuthRepository.instance.usuario.value?.esAdmin ?? false)
      ? const HomeScreen()
      : AdminRepository.instance.dentroDelPanel
      ? pantalla()
      : const AdminAccesoScreen(),
);
