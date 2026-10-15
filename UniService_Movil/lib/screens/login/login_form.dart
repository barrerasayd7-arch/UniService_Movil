import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../admin/admin_widgets.dart';
import 'auth_widgets.dart';
import 'recuperar_password.dart';

/// Pestaña "Iniciar sesión": POST /api/auth/login.
class LoginForm extends StatefulWidget {
  /// Correo que llega desde el registro cuando la cuenta ya existía.
  final String correoInicial;
  const LoginForm({super.key, this.correoInicial = ''});

  @override
  State<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends State<LoginForm> {
  late final _correo = TextEditingController(text: widget.correoInicial);
  final _pass = TextEditingController();
  String? _errorCorreo;
  String? _aviso;
  bool _cargando = false;

  @override
  void didUpdateWidget(LoginForm old) {
    super.didUpdateWidget(old);
    if (widget.correoInicial != old.correoInicial &&
        widget.correoInicial.isNotEmpty) {
      _correo.text = widget.correoInicial;
      _pass.clear();
    }
  }

  @override
  void dispose() {
    _correo.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (_cargando) return;
    final correo = normalizarCorreo(_correo.text);
    if (!regexCorreo.hasMatch(correo)) {
      setState(
        () => _errorCorreo =
            'Escribe tu correo completo, por ejemplo usuario@unicesar.edu.co',
      );
      return;
    }
    if (_pass.text.isEmpty) {
      setState(() => _aviso = 'Escribe tu contraseña.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _cargando = true;
      _aviso = null;
    });
    try {
      final usuario = await AuthRepository.instance.iniciarSesion(
        correo,
        _pass.text,
      );
      if (!mounted) return;
      // Cuenta admin: avisar antes de entrar con privilegios. El panel queda encima
      // del home, así "Volver" o "Seguir como usuario" llevan a la app normal.
      final irAlPanel = usuario.esAdmin && await mostrarAvisoAdmin(context);
      if (!mounted) return;
      final nav = Navigator.of(context);
      nav.pushNamedAndRemoveUntil('/home', (_) => false);
      if (irAlPanel) nav.pushNamed('/admin');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = e.mensaje;
      });
    }
  }

  Future<void> _olvide() async {
    final correo = normalizarCorreo(_correo.text);
    await mostrarRecuperarPassword(
      context,
      correoInicial: regexCorreoInstitucional.hasMatch(correo) ? correo : '',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthField(
            label: 'Correo institucional',
            hint: 'usuario@unicesar.edu.co',
            icon: Icons.mail_outline_rounded,
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            onChanged: (_) => setState(() {
              _errorCorreo = null;
              _aviso = null;
            }),
            errorText: _errorCorreo,
          ),
          AuthField(
            label: 'Contraseña',
            hint: 'Tu contraseña',
            icon: Icons.lock_outline_rounded,
            controller: _pass,
            obscure: true,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            onChanged: (_) => setState(() => _aviso = null),
            onSubmitted: (_) => _entrar(),
          ),
          Transform.translate(
            offset: const Offset(8, -8),
            child: Align(
              alignment: Alignment.centerRight,
              child: AuthTextButton(
                label: '¿Olvidaste tu contraseña?',
                onTap: _olvide,
              ),
            ),
          ),
          AuthAviso(mensaje: _aviso),
          AuthPrimaryButton(
            label: 'Entrar',
            cargando: _cargando,
            onTap: _entrar,
          ),
          const SizedBox(height: 6),
          Center(
            child: AuthTextButton(
              label: 'Continuar sin cuenta',
              color: AppColors.texto2,
              onTap: () =>
                  Navigator.of(context).pushReplacementNamed('/home-guest'),
            ),
          ),
        ],
      ),
    );
  }
}
