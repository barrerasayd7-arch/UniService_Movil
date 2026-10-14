import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'core/app_colors.dart';
import 'data/auth_repository.dart';
import 'screens/home/home_screen.dart';
import 'screens/home_guest/home_guest_screen.dart';
import 'screens/login/auth_widgets.dart';
import 'screens/login/login_screen.dart';
import 'models/servicio.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/service_detail/detail_screen.dart';

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
        // El servicio llega como argumento: Navigator.pushNamed('/servicio', arguments: servicio)
        '/servicio': (ctx) {
          final arg = ModalRoute.of(ctx)?.settings.arguments;
          return DetailScreen(servicio: arg is Servicio ? arg : null);
        },
        '/perfil-externo': (_) => const ProfileScreen(externo: true),
      },
    );
  }
}
