import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'auth_widgets.dart';

/// Panel "Registrarse" (#panel-reg de InicioSesion.jsx).
/// Solo UI + validaciones visuales. Los marcan dónde va la API.
class RegisterForm extends StatefulWidget {
  final VoidCallback onIrALogin;
  const RegisterForm({super.key, required this.onIrALogin});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  final _nombre = TextEditingController();
  final _correo = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();
  final Map<String, String> _errores = {};

  bool _terminos = false;
  bool _enviandoCodigo = false;
  bool _codigoEnviado = false;
  bool _correoVerificado = false; // pasa a true tras validar el código de 6 dígitos
  bool _cargando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _correo.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  // ── Validaciones en tiempo real (mismas reglas de la web) ──
  void _validarNombre(String v) {
    setState(() {
      if (v.trim().length < 3) {
        _errores['nombre'] = 'Mínimo 3 caracteres';
      } else if (v.length > 50) {
        _errores['nombre'] = 'Nombre muy largo';
      } else {
        _errores['nombre'] = '';
      }
    });
  }

  void _validarCorreo(String v) {
    setState(() {
      _errores['correo'] = regexCorreo.hasMatch(v) ? '' : 'Correo inválido';
    });
  }

  void _validarPass(String v) {
    setState(() {
      _errores['pass'] = v.length < 8 ? 'Mínimo 8 caracteres' : '';
      if (_pass2.text.isNotEmpty) {
        _errores['pass2'] = v != _pass2.text ? 'Las contraseñas no coinciden' : '';
      }
    });
  }

  void _validarPass2(String v) {
    setState(() {
      if (v.length < 8) {
        _errores['pass2'] = 'Mínimo 8 caracteres';
      } else if (v != _pass.text) {
        _errores['pass2'] = 'Las contraseñas no coinciden';
      } else {
        _errores['pass2'] = '';
      }
    });
  }

  Future<void> _enviarCodigo() async {
    if (!regexCorreo.hasMatch(_correo.text)) {
      mostrarNotificacion(context, 'Ingresa un correo válido primero');
      return;
    }
    setState(() => _enviandoCodigo = true);
    // (backend): POST /api/Auth/send-code { correo }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _enviandoCodigo = false;
      _codigoEnviado = true;
    });
    //  mostrar el modal de verificación de 6 dígitos (ModalVerificarCodigo)
    mostrarNotificacion(context, 'Aquí se abriría el modal para ingresar el código.', exito: true);
  }

  Future<void> _crearCuenta() async {
    if (_cargando) return;
    if (!_correoVerificado) {
      mostrarNotificacion(context, 'Debes verificar tu correo primero');
      return;
    }
    if (_pass.text.length < 8 ||
        _pass.text != _pass2.text ||
        _nombre.text.trim().length < 3 ||
        !_terminos) {
      mostrarNotificacion(context, 'Revisa los campos del formulario');
      return;
    }
    setState(() => _cargando = true);
    //  POST /api/Auth/register { correo, password, nombre, codigo }
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() => _cargando = false);
    mostrarNotificacion(context, 'Cuenta creada, ya puedes iniciar sesión', exito: true);
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
              _enviandoCodigo
                  ? 'Enviando...'
                  : _codigoEnviado
                      ? 'Reenviar'
                      : 'Enviar código',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          label: 'Nombre completo',
          hint: 'Tu nombre y apellido',
          controller: _nombre,
          onChanged: _validarNombre,
          errorText: _errores['nombre'],
        ),
        AuthField(
          label: 'Correo electrónico',
          hint: 'tu@correo.com',
          controller: _correo,
          keyboardType: TextInputType.emailAddress,
          onChanged: _validarCorreo,
          errorText: _errores['correo'],
          enabled: !_correoVerificado,
          verified: _correoVerificado,
          trailing: _botonEnviarCodigo(),
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
                    side: const BorderSide(color: AppColors.texto2, width: 1.5),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppText.poppins(12.16, color: AppColors.texto2, height: 1.55),
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
                        //
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
    );
  }
}
