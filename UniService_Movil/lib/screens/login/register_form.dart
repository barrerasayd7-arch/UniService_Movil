import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'modal_codigo.dart';

/// Panel "Registrarse". Flujo: correo institucional → código de 6 dígitos →
/// datos personales → POST /api/auth/register.
class RegisterForm extends StatefulWidget {
  final VoidCallback onIrALogin;
  const RegisterForm({super.key, required this.onIrALogin});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _telefono = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final Map<String, String> _errores = {};
  static final _regexTelefono = RegExp(r'^[0-9+\-\s()]{7,20}$');

  bool _terminos = false;
  bool _enviandoCodigo = false;
  String? _verificacionToken; // token de 15 min devuelto al validar el código
  bool _cargando = false;

  bool get _correoVerificado => _verificacionToken != null;

  @override
  void dispose() {
    for (final c in [_nombre, _apellido, _telefono, _correo, _pass, _pass2]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validaciones en tiempo real (mismas reglas que el backend) ──
  String _errorNombre(String v, String campo) {
    final t = v.trim();
    if (t.length < 2) return '$campo: mínimo 2 caracteres';
    if (t.length > 50) return '$campo: máximo 50 caracteres';
    return '';
  }

  String _errorCorreo(String v) =>
      regexCorreoInstitucional.hasMatch(normalizarCorreo(v))
      ? ''
      : 'Usa tu correo @unicesar.edu.co';

  String _errorTelefono(String v) =>
      _regexTelefono.hasMatch(v.trim()) ? '' : 'Entre 7 y 20 dígitos';

  void _validarPass(String v) {
    setState(() {
      _errores['pass'] = v.length < 8 ? 'Mínimo 8 caracteres' : '';
      if (_pass2.text.isNotEmpty) {
        _errores['pass2'] = v != _pass2.text
            ? 'Las contraseñas no coinciden'
            : '';
      }
    });
  }

  void _validarPass2(String v) {
    setState(() {
      _errores['pass2'] = v != _pass.text ? 'Las contraseñas no coinciden' : '';
    });
  }

  Future<void> _enviarCodigo() async {
    final correo = normalizarCorreo(_correo.text);
    final error = _errorCorreo(correo);
    if (error.isNotEmpty) {
      setState(() => _errores['correo'] = error);
      return;
    }
    setState(() => _enviandoCodigo = true);
    try {
      final espera = await AuthRepository.instance.enviarCodigo(correo);
      if (!mounted) return;
      setState(() => _enviandoCodigo = false);
      final r = await mostrarModalCodigo(
        context,
        correo: correo,
        reenviarEn: espera,
      );
      if (r == null || !mounted) return;
      if (r.cuentaExistente) {
        await mostrarNotificacion(
          context,
          'Ya tienes una cuenta con este correo. Inicia sesión con tu contraseña.',
        );
        widget.onIrALogin();
        return;
      }
      setState(() => _verificacionToken = r.token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _enviandoCodigo = false);
      mostrarNotificacion(context, e.mensaje);
    }
  }

  Future<void> _crearCuenta() async {
    if (_cargando) return;
    setState(() {
      _errores['nombre'] = _errorNombre(_nombre.text, 'Nombre');
      _errores['apellido'] = _errorNombre(_apellido.text, 'Apellido');
      _errores['telefono'] = _errorTelefono(_telefono.text);
      _errores['pass'] = _pass.text.length < 8 ? 'Mínimo 8 caracteres' : '';
      _errores['pass2'] = _pass.text != _pass2.text
          ? 'Las contraseñas no coinciden'
          : '';
    });
    if (!_correoVerificado) {
      mostrarNotificacion(
        context,
        'Primero verifica tu correo con el código que te enviamos.',
      );
      return;
    }
    if (_errores.values.any((e) => e.isNotEmpty)) return;
    if (!_terminos) {
      mostrarNotificacion(
        context,
        'Acepta los términos y la política de privacidad para continuar.',
      );
      return;
    }

    setState(() => _cargando = true);
    try {
      await AuthRepository.instance.registrar(
        correo: normalizarCorreo(_correo.text),
        password: _pass.text,
        nombre: _nombre.text.trim(),
        apellido: _apellido.text.trim(),
        telefono: _telefono.text.trim(),
        verificacionToken: _verificacionToken!,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        // El token de verificación dura 15 min: si venció, hay que pedir otro código.
        if (e.status == 400 && e.mensaje.contains('Verificación')) {
          _verificacionToken = null;
        }
      });
      if (e.status == 409) {
        await mostrarNotificacion(context, e.mensaje);
        widget.onIrALogin();
      } else {
        mostrarNotificacion(context, e.mensaje);
      }
    }
  }

  Widget _botonEnviarCodigo() {
    if (_correoVerificado) {
      return Text(
        '✓ Verificado',
        style: AppText.poppins(
          13.12,
          weight: FontWeight.w700,
          color: AppColors.verificado,
        ),
      );
    }
    return Opacity(
      opacity: _enviandoCodigo ? 0.5 : 1,
      child: GestureDetector(
        onTap: _enviandoCodigo ? null : _enviarCodigo,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.a(AppColors.teal, 0.12),
              border: Border.all(color: AppColors.a(AppColors.teal, 0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              _enviandoCodigo ? 'Enviando...' : 'Enviar código',
              style: AppText.poppins(
                12.48,
                weight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
        ),
      ),
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
            controller: _correo,
            keyboardType: TextInputType.emailAddress,
            onChanged: (v) =>
                setState(() => _errores['correo'] = _errorCorreo(v)),
            errorText: _errores['correo'],
            enabled: !_correoVerificado,
            verified: _correoVerificado,
            trailing: _botonEnviarCodigo(),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: AuthField(
                  label: 'Nombre',
                  hint: 'Tu nombre',
                  controller: _nombre,
                  onChanged: (v) => setState(
                    () => _errores['nombre'] = _errorNombre(v, 'Nombre'),
                  ),
                  errorText: _errores['nombre'],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: AuthField(
                  label: 'Apellido',
                  hint: 'Tu apellido',
                  controller: _apellido,
                  onChanged: (v) => setState(
                    () => _errores['apellido'] = _errorNombre(v, 'Apellido'),
                  ),
                  errorText: _errores['apellido'],
                ),
              ),
            ],
          ),
          AuthField(
            label: 'Teléfono',
            hint: '300 123 4567',
            controller: _telefono,
            keyboardType: TextInputType.phone,
            onChanged: (v) =>
                setState(() => _errores['telefono'] = _errorTelefono(v)),
            errorText: _errores['telefono'],
          ),
          AuthField(
            label: 'Contraseña',
            hint: 'Mínimo 8 caracteres',
            controller: _pass,
            obscure: true,
            onChanged: _validarPass,
            errorText: _errores['pass'],
          ),
          AuthField(
            label: 'Confirmar contraseña',
            hint: 'Repite tu contraseña',
            controller: _pass2,
            obscure: true,
            onChanged: _validarPass2,
            errorText: _errores['pass2'],
          ),

          // .terminos
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.a(AppColors.teal, 0.05),
              border: Border.all(color: AppColors.a(AppColors.teal, 0.12)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: Checkbox(
                      value: _terminos,
                      onChanged: (v) => setState(() => _terminos = v ?? false),
                      activeColor: AppColors.teal,
                      checkColor: AppColors.bg,
                      side: const BorderSide(
                        color: AppColors.texto2,
                        width: 1.5,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppText.poppins(
                        12.16,
                        color: AppColors.texto2,
                        height: 1.55,
                      ),
                      children: [
                        const TextSpan(text: 'Acepto los '),
                        TextSpan(
                          text: 'Términos y Condiciones',
                          style: AppText.poppins(
                            12.16,
                            weight: FontWeight.w600,
                            color: AppColors.teal,
                            height: 1.55,
                          ),
                          // navegar a /terminos con un TapGestureRecognizer
                        ),
                        const TextSpan(text: ' y la '),
                        TextSpan(
                          text: 'Política de Privacidad',
                          style: AppText.poppins(
                            12.16,
                            weight: FontWeight.w600,
                            color: AppColors.teal,
                            height: 1.55,
                          ),
                        ),
                        const TextSpan(text: '.'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          AuthPrimaryButton(
            label: _cargando ? 'Creando cuenta...' : 'Crear cuenta →',
            onTap: _cargando ? null : _crearCuenta,
          ),
          const SizedBox(height: 12),

          AuthPie(
            texto: '¿Ya tienes cuenta?',
            link: 'Inicia sesión',
            onTap: widget.onIrALogin,
          ),
        ],
      ),
    );
  }
}
