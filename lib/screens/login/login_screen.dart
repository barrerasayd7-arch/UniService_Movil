import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/cosmos_background.dart';
import 'auth_lateral.dart';
import 'auth_widgets.dart';
import 'login_form.dart';
import 'register_form.dart';

/// Vista de Login + Registro (InicioSesion.jsx).
/// En la web ambos formularios viven en la misma página con dos tabs.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  int _tab = 0; // 0 = iniciar sesión, 1 = registrarse

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.of(context).size.width;
    final apilado = ancho < Breakpoints.authStack; // una sola columna

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          // La escena cósmica solo se muestra en pantallas anchas (igual que la web)
          if (!apilado) const Positioned.fill(child: CosmosBackground()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: apilado ? 420 : 820),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: 1),
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                    builder: (context, v, child) => Opacity(
                      opacity: v,
                      child: Transform.translate(
                        offset: Offset(0, (1 - v) * 20),
                        child: child,
                      ),
                    ),
                    child: _AuthBox(
                      apilado: apilado,
                      tab: _tab,
                      onTab: (i) => setState(() => _tab = i),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.auth-box`: tarjeta con la columna lateral y el formulario.
class _AuthBox extends StatelessWidget {
  final bool apilado;
  final int tab;
  final ValueChanged<int> onTab;
  const _AuthBox({required this.apilado, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    final formulario = _Formulario(apilado: apilado, tab: tab, onTab: onTab);

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 60,
            offset: const Offset(0, 20),
          ),
          BoxShadow(
            color: AppColors.a(AppColors.teal, 0.05),
            spreadRadius: 1,
          ),
        ],
      ),
      child: apilado
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AuthLateral(compacto: true),
                formulario,
              ],
            )
                    : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 460),
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(child: formulario),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: box.maxWidth / 2,
                      child: const AuthLateral(compacto: false),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// `.auth-formulario`: título, tabs y los dos paneles.
class _Formulario extends StatelessWidget {
  final bool apilado;
  final int tab;
  final ValueChanged<int> onTab;
  const _Formulario({required this.apilado, required this.tab, required this.onTab});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: apilado ? 24 : 32, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // .auth-logo
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: Column(
              children: [
                Text(
                  'BIENVENIDO 👋',
                  style: AppText.poppins(
                    12,
                    weight: FontWeight.w600,
                    color: AppColors.teal,
                    spacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    style: AppText.serif(22.4, height: 1.3),
                    children: [
                      const TextSpan(text: 'Accede a la '),
                      TextSpan(
                        text: 'plataforma',
                        style: AppText.serif(22.4, color: AppColors.teal, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  width: 40,
                  height: 2,
                  color: AppColors.a(AppColors.teal, 0.7),
                ),
              ],
            ),
          ),

          AuthTabs(index: tab, onChanged: onTab),

          // Ambos paneles se mantienen montados (conservan lo escrito al cambiar de tab)
          Visibility(
            visible: tab == 0,
            maintainState: true,
            child: LoginForm(onIrARegistro: () => onTab(1)),
          ),
          Visibility(
            visible: tab == 1,
            maintainState: true,
            child: RegisterForm(onIrALogin: () => onTab(0)),
          ),
        ],
      ),
    );
  }
}
