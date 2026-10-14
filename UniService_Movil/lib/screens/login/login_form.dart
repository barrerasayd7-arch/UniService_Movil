import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';

/// Panel "Iniciar sesión" (#panel-login de InicioSesion.jsx): POST /api/auth/login.
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
      _errores['correo'] = regexCorreo.hasMatch(normalizarCorreo(v))
          ? ''
          : 'Correo inválido';
    });
  }

  void _validarPass(String v) {
    setState(() {
      _errores['pass'] = v.isEmpty ? 'Ingresa tu contraseña' : '';
    });
  }

  Future<void> _entrar() async {
    if (_cargando) return;
    final correo = normalizarCorreo(_correo.text);
    if (!regexCorreo.hasMatch(correo)) {
      mostrarNotificacion(context, 'Ingresa un correo válido');
      return;
    }
    if (_pass.text.isEmpty) {
      mostrarNotificacion(context, 'Ingresa tu contraseña');
      return;
    }
    setState(() => _cargando = true);
    try {
      await AuthRepository.instance.iniciarSesion(correo, _pass.text);
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarNotificacion(context, e.mensaje);
    }
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
          onTap: () =>
              Navigator.of(context).pushReplacementNamed('/home-guest'),
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
