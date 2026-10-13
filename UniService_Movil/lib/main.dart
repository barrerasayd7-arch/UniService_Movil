import 'package:flutter/material.dart';

import 'core/app_colors.dart';
import 'screens/home/home_screen.dart';
import 'screens/home_guest/home_guest_screen.dart';
import 'screens/login/login_screen.dart';
import 'models/servicio.dart';
import 'screens/profile/profile_screen.dart';
import 'screens/service_detail/detail_screen.dart';

void main() {
  runApp(const UniServiceApp());
}

class UniServiceApp extends StatelessWidget {
  const UniServiceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UniService',
      debugShowCheckedModeBanner: false,
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
      // En la web "/" redirige a /home-guest.
      initialRoute: '/home',
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
