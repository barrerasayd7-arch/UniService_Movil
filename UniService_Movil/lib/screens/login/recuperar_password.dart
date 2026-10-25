// Archivo: recuperar_password.dart
// Responsabilidad: hoja inferior de dos pasos para restablecer la contraseña con código de correo.
// Se usa desde: login_form.dart ("¿Olvidaste tu contraseña?").

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'modal_codigo.dart';

/// Hoja inferior para restablecer la contraseña con el código del correo institucional.
/// Paso 1: correo → código de 6 dígitos. Paso 2: contraseña nueva → entra a la app.
/// [correoInicial] se precarga si el login ya tenía un correo válido.
Future<void> mostrarRecuperarPassword(
  BuildContext context, {
  String correoInicial = '',
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _RecuperarPassword(correoInicial: correoInicial),
  );
}

class _RecuperarPassword extends StatefulWidget {
  final String correoInicial;
  const _RecuperarPassword({required this.correoInicial});

  @override
  State<_RecuperarPassword> createState() => _RecuperarPasswordState();
}

class _RecuperarPasswordState extends State<_RecuperarPassword> {
  // --- Estado de los dos pasos ---

  late final _correo = TextEditingController(text: widget.correoInicial);
  final _nueva = TextEditingController();
  String?
  _token; // null = paso 1 (correo); con valor = paso 2 (contraseña nueva)
  String? _errorCampo;
  String? _aviso;
  bool _cargando = false;

  @override
  void dispose() {
    _correo.dispose();
    _nueva.dispose();
    super.dispose();
  }

  // Envía el código y, si la cuenta existe, guarda el token para el paso 2.
  Future<void> _enviarCodigo() async {
    final correo = normalizarCorreo(_correo.text);
    if (!regexCorreoInstitucional.hasMatch(correo)) {
      setState(() => _errorCampo = 'Usa tu correo @unicesar.edu.co');
      return;
    }
    setState(() {
      _cargando = true;
      _aviso = null;
    });
    try {
      final espera = await AuthRepository.instance.enviarCodigo(correo);
      if (!mounted) return;
      setState(() => _cargando = false);
      final r = await mostrarModalCodigo(
        context,
        correo: correo,
        reenviarEn: espera,
      );
      if (r == null || !mounted) return;
      setState(() {
        if (r.cuentaExistente) {
          _token = r.token;
        } else {
          _aviso =
              'No hay una cuenta con este correo. Créala desde la pestaña Crear cuenta.';
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _cargando = false;
          _aviso = e.mensaje;
        });
      }
    }
  }

  // Guarda la contraseña nueva con el token de verificación y entra a la app.
  Future<void> _guardar() async {
    if (_nueva.text.length < 8) {
      setState(() => _errorCampo = 'Usa al menos 8 caracteres');
      return;
    }
    setState(() {
      _cargando = true;
      _aviso = null;
    });
    try {
      await AuthRepository.instance.restablecerPassword(
        correo: normalizarCorreo(_correo.text),
        verificacionToken: _token!,
        nuevaPassword: _nueva.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = e.mensaje;
        // El token dura 15 minutos: si venció, se vuelve al paso del correo.
        if (e.status == 400) _token = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final verificado = _token != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        18 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Restablecer contraseña', style: AppText.serif(26)),
            const SizedBox(height: 6),
            Text(
              verificado
                  ? 'Correo verificado. Elige una contraseña nueva.'
                  : 'Te enviaremos un código a tu correo institucional.',
              style: AppText.poppins(14, color: AppColors.texto2, height: 1.45),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: verificado
                  ? AuthField(
                      key: const ValueKey('nueva'),
                      label: 'Contraseña nueva',
                      hint: 'Mínimo 8 caracteres',
                      icon: Icons.lock_outline_rounded,
                      controller: _nueva,
                      obscure: true,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.newPassword],
                      errorText: _errorCampo,
                      onChanged: (_) => setState(() => _errorCampo = null),
                      onSubmitted: (_) => _guardar(),
                    )
                  : AuthField(
                      key: const ValueKey('correo'),
                      label: 'Correo institucional',
                      hint: 'usuario@unicesar.edu.co',
                      icon: Icons.mail_outline_rounded,
                      controller: _correo,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.send,
                      autofillHints: const [AutofillHints.email],
                      errorText: _errorCampo,
                      onChanged: (_) => setState(() {
                        _errorCampo = null;
                        _aviso = null;
                      }),
                      onSubmitted: (_) => _enviarCodigo(),
                    ),
            ),
            AuthAviso(mensaje: _aviso),
            AuthPrimaryButton(
              label: verificado ? 'Guardar y entrar' : 'Enviar código',
              cargando: _cargando,
              onTap: verificado ? _guardar : _enviarCodigo,
            ),
          ],
        ),
      ),
    );
  }
}
