import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/admin_repository.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../login/auth_widgets.dart';
import '../login/modal_codigo.dart';
import 'admin_widgets.dart';

/// Puerta del panel: pide la contraseña de administrador (distinta a la de la cuenta).
/// Si aún no existe, o el admin la olvidó, la crea tras confirmar el correo con un código.
class AdminAccesoScreen extends StatefulWidget {
  const AdminAccesoScreen({super.key});

  @override
  State<AdminAccesoScreen> createState() => _AdminAccesoScreenState();
}

class _AdminAccesoScreenState extends State<AdminAccesoScreen> {
  final _repo = AdminRepository.instance;
  final _clave = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  EstadoAccesoAdmin? _estado;
  String? _errorCarga;
  bool _restablecer = false; // "¿La olvidaste?" lleva al flujo de creación
  String?
  _verificacion; // token del código del correo: paso de la contraseña nueva
  String? _aviso;
  bool _enviando = false;
  DateTime? _bloqueadoHasta;
  Timer? _desbloqueo;

  bool get _modoCrear => !_estado!.configurada || _restablecer;
  bool get _bloqueado => _bloqueadoHasta != null;

  bool get _largoOk => _nueva.text.length >= 10;
  bool get _mezclaOk =>
      RegExp(r'\p{L}', unicode: true).hasMatch(_nueva.text) &&
      RegExp(r'\d').hasMatch(_nueva.text);
  bool get _noCoincide =>
      _confirmar.text.isNotEmpty && !_nueva.text.startsWith(_confirmar.text);
  bool get _nuevaLista =>
      _largoOk && _mezclaOk && _confirmar.text == _nueva.text;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _desbloqueo?.cancel();
    _clave.dispose();
    _nueva.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _estado = null;
      _errorCarga = null;
    });
    try {
      final estado = await _repo.estado();
      if (!mounted) return;
      setState(() => _estado = estado);
      _bloquearHasta(estado.bloqueadoHasta);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    }
  }

  /// Un único temporizador hasta el fin del bloqueo (sin ticks por segundo).
  void _bloquearHasta(DateTime? hasta) {
    _desbloqueo?.cancel();
    final restante = hasta?.difference(DateTime.now().toUtc());
    if (restante == null || restante.isNegative) {
      setState(() => _bloqueadoHasta = null);
      return;
    }
    setState(() => _bloqueadoHasta = hasta);
    _desbloqueo = Timer(restante, () {
      if (mounted) {
        setState(() {
          _bloqueadoHasta = null;
          _aviso = null;
        });
      }
    });
  }

  void _abrirPanel() => Navigator.of(context).pushReplacementNamed('/admin');

  void _volver() {
    final nav = Navigator.of(context);
    if (nav.canPop()) {
      nav.pop();
    } else {
      nav.pushReplacementNamed('/home');
    }
  }

  Future<void> _entrar() async {
    if (_enviando || _bloqueado || _clave.text.isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await _repo.entrar(_clave.text);
      if (mounted) _abrirPanel();
    } on ApiException catch (e) {
      if (!mounted) return;
      _clave.clear();
      setState(() {
        _enviando = false;
        _aviso = e.mensaje;
      });
      if (e.status == 429) {
        _bloquearHasta(AdminRepository.fechaApi(e.datos?['bloqueado_hasta']));
      }
      if (e.status == 409) _cargar(); // la contraseña dejó de existir
    }
  }

  Future<void> _enviarCodigo() async {
    if (_enviando) return;
    final correo = _estado!.correo;
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      final espera = await AuthRepository.instance.enviarCodigo(correo);
      if (!mounted) return;
      setState(() => _enviando = false);
      final r = await mostrarModalCodigo(
        context,
        correo: correo,
        reenviarEn: espera,
        textoSalir: 'Cancelar',
      );
      if (r != null && mounted) setState(() => _verificacion = r.token);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _aviso = e.mensaje;
      });
    }
  }

  Future<void> _guardar() async {
    if (_enviando || !_nuevaLista) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _enviando = true;
      _aviso = null;
    });
    try {
      await _repo.crearClave(
        verificacionToken: _verificacion!,
        clave: _nueva.text,
      );
      if (mounted) _abrirPanel();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _enviando = false;
        _aviso = e.mensaje;
        // El código venció (dura 15 minutos): hay que pedir otro.
        if (e.mensaje.startsWith('El código')) _verificacion = null;
      });
    }
  }

  void _irARestablecer(bool activo) {
    setState(() {
      _restablecer = activo;
      _verificacion = null;
      _aviso = null;
      _clave.clear();
      _nueva.clear();
      _confirmar.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Volver a la app',
          icon: const Icon(Icons.arrow_back_rounded, color: AppColors.texto),
          onPressed: _volver,
        ),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: _contenido(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _contenido() {
    if (_errorCarga != null) {
      return _Estado(
        icono: Icons.cloud_off_rounded,
        mensaje: _errorCarga!,
        accion: 'Reintentar',
        onAccion: _cargar,
      );
    }
    if (_estado == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.4,
              color: AppColors.admin,
              semanticsLabel: 'Cargando',
            ),
          ),
        ),
      );
    }

    final (titulo, descripcion, formulario) = !_modoCrear
        ? (
            'Confirma que eres tú',
            _textoSimple(
              'Escribe tu contraseña de administrador. Es distinta a la que usas para iniciar sesión.',
            ),
            _formEntrar(),
          )
        : _verificacion == null
        ? (
            _estado!.configurada
                ? 'Restablece tu contraseña de administrador'
                : 'Crea tu contraseña de administrador',
            _textoCorreo(),
            _formCodigo(),
          )
        : (
            _estado!.configurada
                ? 'Restablece tu contraseña de administrador'
                : 'Crea tu contraseña de administrador',
            _textoSimple(
              'Correo confirmado. Elige una contraseña que no uses en ningún otro sitio, '
              'ni siquiera en tu cuenta de UniService.',
            ),
            _formNueva(),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const InsigniaAdmin(),
        const SizedBox(height: 18),
        Semantics(
          header: true,
          child: Text(titulo, style: AppText.serif(32, height: 1.12)),
        ),
        const SizedBox(height: 10),
        descripcion,
        const SizedBox(height: 28),
        formulario,
      ],
    );
  }

  Widget _textoSimple(String texto) => Text(
    texto,
    style: AppText.poppins(15, color: AppColors.texto2, height: 1.5),
  );

  Widget _textoCorreo() {
    final base = AppText.poppins(15, color: AppColors.texto2, height: 1.5);
    return Text.rich(
      TextSpan(
        style: base,
        children: [
          const TextSpan(
            text:
                'Es una segunda contraseña, solo para el panel. Antes confirmaremos '
                'que eres tú con un código que enviaremos a ',
          ),
          TextSpan(
            text: _estado!.correo,
            style: base.copyWith(
              color: AppColors.texto,
              fontWeight: FontWeight.w600,
            ),
          ),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }

  Widget _formEntrar() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Sin autofillHints: el gestor de contraseñas no debe ofrecer la de la cuenta.
        AuthField(
          label: 'Contraseña de administrador',
          hint: 'No es la de tu cuenta',
          icon: Icons.key_rounded,
          controller: _clave,
          obscure: true,
          enabled: !_bloqueado && !_enviando,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _aviso = null),
          onSubmitted: (_) => _entrar(),
        ),
        AuthAviso(mensaje: _aviso),
        AuthPrimaryButton(
          label: _bloqueado
              ? 'Disponible a las ${horaCorta(_bloqueadoHasta!)}'
              : 'Entrar al panel',
          color: AppColors.admin,
          colorHover: AppColors.adminHover,
          cargando: _enviando,
          onTap: _bloqueado || _clave.text.isEmpty ? null : _entrar,
        ),
        const SizedBox(height: 8),
        Center(
          child: AuthTextButton(
            label: '¿Olvidaste tu contraseña de administrador?',
            color: AppColors.admin,
            onTap: _enviando ? null : () => _irARestablecer(true),
          ),
        ),
      ],
    );
  }

  Widget _formCodigo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthAviso(mensaje: _aviso),
        AuthPrimaryButton(
          label: 'Enviar código',
          color: AppColors.admin,
          colorHover: AppColors.adminHover,
          cargando: _enviando,
          onTap: _enviarCodigo,
        ),
        if (_restablecer) ...[
          const SizedBox(height: 8),
          Center(
            child: AuthTextButton(
              label: 'Ya la recuerdo',
              color: AppColors.texto2,
              onTap: _enviando ? null : () => _irARestablecer(false),
            ),
          ),
        ],
      ],
    );
  }

  Widget _formNueva() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthField(
          label: 'Contraseña de administrador nueva',
          hint: 'Mínimo 10 caracteres',
          icon: Icons.key_rounded,
          controller: _nueva,
          obscure: true,
          enabled: !_enviando,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) => setState(() => _aviso = null),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Requisito(texto: 'Al menos 10 caracteres', cumplido: _largoOk),
              _Requisito(texto: 'Letras y números', cumplido: _mezclaOk),
              const _Requisito(
                texto: 'Distinta a la contraseña de tu cuenta',
                cumplido: null,
              ),
            ],
          ),
        ),
        AuthField(
          label: 'Repite la contraseña',
          hint: 'Escríbela otra vez',
          icon: Icons.key_rounded,
          controller: _confirmar,
          obscure: true,
          enabled: !_enviando,
          textInputAction: TextInputAction.done,
          errorText: _noCoincide ? 'No coincide con la anterior' : null,
          onChanged: (_) => setState(() => _aviso = null),
          onSubmitted: (_) => _guardar(),
        ),
        AuthAviso(mensaje: _aviso),
        AuthPrimaryButton(
          label: 'Guardar y entrar al panel',
          color: AppColors.admin,
          colorHover: AppColors.adminHover,
          cargando: _enviando,
          onTap: _nuevaLista ? _guardar : null,
        ),
      ],
    );
  }
}

/// Requisito de la contraseña nueva. cumplido null = lo comprueba el servidor al guardar.
/// El ícono cambia de forma, no sólo de color.
class _Requisito extends StatelessWidget {
  final String texto;
  final bool? cumplido;
  const _Requisito({required this.texto, required this.cumplido});

  @override
  Widget build(BuildContext context) {
    final (icono, color) = switch (cumplido) {
      true => (Icons.check_circle_rounded, AppColors.verificado),
      false => (Icons.radio_button_unchecked_rounded, AppColors.placeholder),
      null => (Icons.info_outline_rounded, AppColors.placeholder),
    };
    return Semantics(
      label: '$texto${cumplido == true ? ', cumplido' : ''}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Icon(icono, size: 17, color: color),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                texto,
                style: AppText.poppins(
                  13.5,
                  color: cumplido == true ? AppColors.texto : AppColors.texto2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Estado extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String accion;
  final VoidCallback onAccion;
  const _Estado({
    required this.icono,
    required this.mensaje,
    required this.accion,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(icono, size: 36, color: AppColors.texto2),
          const SizedBox(height: 14),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: AppText.poppins(15, color: AppColors.texto, height: 1.5),
          ),
          const SizedBox(height: 22),
          AuthPrimaryButton(
            label: accion,
            color: AppColors.admin,
            colorHover: AppColors.adminHover,
            onTap: onAccion,
          ),
        ],
      ),
    );
  }
}
