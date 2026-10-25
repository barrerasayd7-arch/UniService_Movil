// Archivo: register_form.dart
// Responsabilidad: pestaña de creación de cuenta en dos pasos (verificar correo y capturar datos).
// Se usa desde: login_screen.dart (_Formulario).

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';
import 'modal_codigo.dart';

/// Pestaña "Crear cuenta", en dos pasos:
/// 1. Correo institucional → código de 6 dígitos.
/// 2. Datos personales y contraseña → POST /api/auth/register.
/// [onIrALogin] permite volver al login (con el correo si la cuenta ya existía).
class RegisterForm extends StatefulWidget {
  /// Lleva a "Iniciar sesión" (con el correo, si ya tenía cuenta).
  final void Function([String? correo]) onIrALogin;
  const RegisterForm({super.key, required this.onIrALogin});

  @override
  State<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends State<RegisterForm> {
  // --- Estado y controladores ---

  final _correo = TextEditingController();
  final _nombre = TextEditingController();
  final _apellido = TextEditingController();
  final _telefono = TextEditingController();
  final _pass = TextEditingController();
  final Map<String, String?> _errores = {};
  static final _regexTelefono = RegExp(r'^[0-9+\-\s()]{7,20}$');

  String? _verificacionToken; // token de 15 min devuelto al validar el código
  String? _aviso;
  bool _terminos = false;
  bool _cargando = false;

  bool get _verificado => _verificacionToken != null;

  @override
  void dispose() {
    for (final c in [_correo, _nombre, _apellido, _telefono, _pass]) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Validaciones (mismas reglas que el backend) ──
  String? _errorNombre(String v, String campo) {
    final t = v.trim();
    if (t.length < 2) return 'Escribe tu $campo';
    if (t.length > 50) return 'Máximo 50 caracteres';
    return null;
  }

  void _limpiar(String campo) => setState(() {
    _errores[campo] = null;
    _aviso = null;
  });

  // Verifica el correo; si la cuenta ya existe, salta al login con ese correo.
  Future<void> _enviarCodigo() async {
    final correo = normalizarCorreo(_correo.text);
    if (!regexCorreoInstitucional.hasMatch(correo)) {
      setState(() => _errores['correo'] = 'Usa tu correo @unicesar.edu.co');
      return;
    }
    FocusScope.of(context).unfocus();
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
      if (r.cuentaExistente) {
        // Ya tiene cuenta: a "Iniciar sesión" con el correo escrito.
        widget.onIrALogin(correo);
        return;
      }
      setState(() => _verificacionToken = r.token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _aviso = e.mensaje;
      });
    }
  }

  void _cambiarCorreo() => setState(() {
    _verificacionToken = null;
    _aviso = null;
  });

  // Valida todos los campos, exige términos y registra con el token de verificación.
  Future<void> _crearCuenta() async {
    if (_cargando) return;
    setState(() {
      _errores['nombre'] = _errorNombre(_nombre.text, 'nombre');
      _errores['apellido'] = _errorNombre(_apellido.text, 'apellido');
      _errores['telefono'] = _regexTelefono.hasMatch(_telefono.text.trim())
          ? null
          : 'Escribe un teléfono de 7 a 20 dígitos';
      _errores['pass'] = _pass.text.length < 8
          ? 'Usa al menos 8 caracteres'
          : null;
      _aviso = null;
    });
    if (_errores.values.any((e) => e != null)) return;
    if (!_terminos) {
      setState(
        () => _aviso =
            'Acepta los términos y la política de privacidad para continuar.',
      );
      return;
    }

    FocusScope.of(context).unfocus();
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
        _aviso = e.mensaje;
        // El token de verificación dura 15 min: si venció, hay que pedir otro código.
        if (e.status == 400 && e.mensaje.contains('Verificación'))
          _verificacionToken = null;
      });
      if (e.status == 409) widget.onIrALogin(normalizarCorreo(_correo.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AutofillGroup(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _verificado ? _pasoDatos() : _pasoCorreo(),
        ),
      ),
    );
  }

  // Paso 1: pedir el correo institucional y su código.
  List<Widget> _pasoCorreo() => [
    AuthField(
      label: 'Correo institucional',
      hint: 'usuario@unicesar.edu.co',
      icon: Icons.mail_outline_rounded,
      controller: _correo,
      keyboardType: TextInputType.emailAddress,
      textInputAction: TextInputAction.send,
      autofillHints: const [AutofillHints.email],
      onChanged: (_) => _limpiar('correo'),
      onSubmitted: (_) => _enviarCodigo(),
      errorText: _errores['correo'],
    ),
    Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 16),
      child: Text(
        'Te enviaremos un código de 6 dígitos para confirmar que es tuyo.',
        style: AppText.poppins(13, color: AppColors.texto2, height: 1.45),
      ),
    ),
    AuthAviso(mensaje: _aviso),
    AuthPrimaryButton(
      label: 'Enviar código',
      cargando: _cargando,
      onTap: _enviarCodigo,
    ),
    const SizedBox(height: 8),
  ];

  // Paso 2: datos personales y contraseña, con el correo ya verificado.
  List<Widget> _pasoDatos() => [
    // Correo ya verificado, con opción de cambiarlo.
    Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.only(left: 12),
      decoration: BoxDecoration(
        color: AppColors.a(AppColors.verificado, 0.08),
        border: Border.all(color: AppColors.a(AppColors.verificado, 0.35)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_outlined,
            size: 18,
            color: AppColors.verificado,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              normalizarCorreo(_correo.text),
              overflow: TextOverflow.ellipsis,
              style: AppText.poppins(14, color: AppColors.texto),
            ),
          ),
          AuthTextButton(
            label: 'Cambiar',
            onTap: _cargando ? null : _cambiarCorreo,
          ),
        ],
      ),
    ),
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: AuthField(
            label: 'Nombre',
            hint: 'Nombre',
            controller: _nombre,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.givenName],
            onChanged: (_) => _limpiar('nombre'),
            errorText: _errores['nombre'],
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AuthField(
            label: 'Apellido',
            hint: 'Apellido',
            controller: _apellido,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.familyName],
            onChanged: (_) => _limpiar('apellido'),
            errorText: _errores['apellido'],
          ),
        ),
      ],
    ),
    AuthField(
      label: 'Teléfono',
      hint: '300 123 4567',
      icon: Icons.phone_outlined,
      controller: _telefono,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.next,
      autofillHints: const [AutofillHints.telephoneNumber],
      onChanged: (_) => _limpiar('telefono'),
      errorText: _errores['telefono'],
    ),
    AuthField(
      label: 'Contraseña',
      hint: 'Mínimo 8 caracteres',
      icon: Icons.lock_outline_rounded,
      controller: _pass,
      obscure: true,
      textInputAction: TextInputAction.done,
      autofillHints: const [AutofillHints.newPassword],
      onChanged: (_) => _limpiar('pass'),
      errorText: _errores['pass'],
    ),
    _Terminos(
      valor: _terminos,
      onChanged: (v) => setState(() => _terminos = v),
    ),
    AuthAviso(mensaje: _aviso),
    AuthPrimaryButton(
      label: 'Crear cuenta',
      cargando: _cargando,
      onTap: _crearCuenta,
    ),
    const SizedBox(height: 8),
  ];
}

/// Casilla de aceptación; toda la fila es tocable.
class _Terminos extends StatelessWidget {
  final bool valor;
  final ValueChanged<bool> onChanged;
  const _Terminos({required this.valor, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final enlace = AppText.poppins(
      13,
      weight: FontWeight.w600,
      color: AppColors.teal,
      height: 1.45,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onChanged(!valor),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 32,
                height: 24,
                child: Checkbox(
                  value: valor,
                  onChanged: (v) => onChanged(v ?? false),
                  activeColor: AppColors.teal,
                  checkColor: AppColors.bg,
                  side: const BorderSide(color: AppColors.texto2, width: 1.5),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: AppText.poppins(
                      13,
                      color: AppColors.texto2,
                      height: 1.45,
                    ),
                    children: [
                      const TextSpan(text: 'Acepto los '),
                      // Pendiente: enlazar cuando existan las páginas de términos y privacidad.
                      TextSpan(text: 'términos', style: enlace),
                      const TextSpan(text: ' y la '),
                      TextSpan(text: 'política de privacidad', style: enlace),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
