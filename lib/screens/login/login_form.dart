import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'auth_widgets.dart';

/// Panel "Iniciar sesión" (#panel-login de InicioSesion.jsx).
/// Solo UI + validaciones visuales. La llamada a la API va en [_entrar].
class LoginForm extends StatefulWidget {
  final VoidCallback onIrARegistro;
  const LoginForm({super.key, required this.onIrARegistro});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  final _correo = TextEditingController();
  final _pass = TextEditingController();
  final Map<String, String> _errores = {};
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _validarCorreo(String v) {
    setState(() {
      _errores['correo'] = regexCorreo.hasMatch(v) ? '' : 'Correo inválido';
    });
  }

  void _validarPass(String v) {
    setState(() {
      _errores['pass'] = v.length < 8 ? 'Mínimo 8 caracteres' : '';
    });
  }

  Future<void> _entrar() async {
    if (_cargando) return;
    if (_correo.text.isEmpty || !regexCorreo.hasMatch(_correo.text)) {
      mostrarNotificacion(context, 'Ingresa un correo válido');
      return;
    }
    if (_pass.text.length < 8) {
      mostrarNotificacion(context, 'Mínimo 8 caracteres');
      return;
    }
    setState(() => _cargando = true);
    // (backend): POST /api/auth/login { correo, password }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _cargando = false);
    mostrarNotificacion(
      context,
      'Aquí iría el login real (solo se implementó la vista).',
      exito: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          label: 'Correo electrónico',
          hint: 'tu@correo.com',
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          onChanged: _validarCorreo,
          errorText: _errores['correo'],
        ),
        AuthField(
          label: 'Contraseña',
          hint: 'Tu contraseña',
          controller: _pass,
          obscure: true,
          onChanged: _validarPass,
          errorText: _errores['pass'],
        ),

        // ¿Olvidaste tu contraseña?
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: () {
                //  abrir flujo de recuperación (ModalRecuperarClave)
              },
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Text(
                  '¿Olvidaste tu contraseña?',
                  style: AppText.poppins(
                    12.32,
                    weight: FontWeight.w500,
                    color: AppColors.teal,
                  ),
                ),
              ),
            ),
          ),
        ),

        // .botones-login
        const SizedBox(height: 10),
        AuthPrimaryButton(
          label: _cargando ? 'Entrando...' : 'Entrar →',
          onTap: _cargando ? null : _entrar,
        ),
        const SizedBox(height: 8),
        AuthSecondaryButton(
          label: 'Entrar como invitado',
          onTap: () => Navigator.of(context).pushReplacementNamed('/home-guest'),
        ),
        const SizedBox(height: 12),

        const AuthSeparator(text: 'o continúa con'),

        GoogleButton(
          onTap: () {
            // (backend): flujo de Google Sign-In
          },
        ),
        const SizedBox(height: 14),

        AuthPie(
          texto: '¿No tienes cuenta?',
          link: 'Regístrate gratis',
          onTap: widget.onIrARegistro,
        ),
      ],
    );
  }
}
