import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../widgets/animacion_ambiental.dart';
import '../../widgets/cosmos_background.dart';
import 'auth_lateral.dart';
import 'auth_widgets.dart';
import 'login_form.dart';
import 'register_form.dart';

/// Login + registro en una sola tarjeta con dos pestañas.
/// Celular: franja de marca arriba y formulario debajo, sin desplazarse.
/// Pantallas anchas: marca a la izquierda y formulario a la derecha.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  /// Alto aproximado de la tarjeta con la pestaña de login (marca + formulario).
  static const double _altoLogin = 570;

  int _tab = 0; // 0 = iniciar sesión, 1 = crear cuenta
  String _correoLogin = ''; // para pasar el correo del registro al login

  void _irALogin([String? correo]) => setState(() {
    _tab = 0;
    if (correo != null) _correoLogin = correo;
  });

  @override
  Widget build(BuildContext context) {
    final apilado = MediaQuery.sizeOf(context).width < Breakpoints.authStack;

    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(
        children: [
          if (!apilado)
            const Positioned.fill(
              child: AnimacionAmbiental(child: CosmosBackground()),
            ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, box) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: apilado ? 14 : 16,
                  vertical: 14,
                ),
                child: ConstrainedBox(
                  // Desplazable sólo si no cabe (teclado abierto, texto grande).
                  constraints: BoxConstraints(minHeight: box.maxHeight - 28),
                  child: Align(
                    // Celular: la tarjeta se ancla arriba a la altura que centra el login,
                    // así marca y pestañas no saltan al cambiar a "Crear cuenta".
                    alignment: apilado ? Alignment.topCenter : Alignment.center,
                    child: Padding(
                      padding: EdgeInsets.only(
                        top: apilado
                            ? math.max(0, (box.maxHeight - _altoLogin) / 2)
                            : 0,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: apilado ? 440 : 820,
                          ),
                          child: _AuthBox(
                            apilado: apilado,
                            tab: _tab,
                            onTab: (i) => setState(() => _tab = i),
                            formulario: _Formulario(
                              tab: _tab,
                              correoLogin: _correoLogin,
                              onTab: (i) => setState(() => _tab = i),
                              onIrALogin: _irALogin,
                            ),
                          ),
                        ),
                      ),
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

/// Tarjeta con la marca y el formulario.
class _AuthBox extends StatelessWidget {
  final bool apilado;
  final int tab;
  final ValueChanged<int> onTab;
  final Widget formulario;
  const _AuthBox({
    required this.apilado,
    required this.tab,
    required this.onTab,
    required this.formulario,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borde),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(77),
            blurRadius: 40,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: apilado
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const AnimacionAmbiental(child: AuthLateral(compacto: true)),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: formulario,
                ),
              ],
            )
          // La marca usa LayoutBuilder (no admite IntrinsicHeight): se posiciona sobre
          // la mitad izquierda y toma la altura que dicte el formulario.
          : ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 540),
              child: LayoutBuilder(
                builder: (context, box) => Stack(
                  children: [
                    Row(
                      children: [
                        const Expanded(child: SizedBox.shrink()),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(32, 32, 32, 20),
                            child: formulario,
                          ),
                        ),
                      ],
                    ),
                    Positioned(
                      left: 0,
                      top: 0,
                      bottom: 0,
                      width: box.maxWidth / 2,
                      child: const AnimacionAmbiental(
                        child: AuthLateral(compacto: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

/// Pestañas y los dos formularios (ambos montados: conservan lo escrito al cambiar).
class _Formulario extends StatelessWidget {
  final int tab;
  final String correoLogin;
  final ValueChanged<int> onTab;
  final void Function([String? correo]) onIrALogin;
  const _Formulario({
    required this.tab,
    required this.correoLogin,
    required this.onTab,
    required this.onIrALogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthTabs(index: tab, onChanged: onTab),
        Visibility(
          visible: tab == 0,
          maintainState: true,
          child: LoginForm(correoInicial: correoLogin),
        ),
        Visibility(
          visible: tab == 1,
          maintainState: true,
          child: RegisterForm(onIrALogin: onIrALogin),
        ),
      ],
    );
  }
}
