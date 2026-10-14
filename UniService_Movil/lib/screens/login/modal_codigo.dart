import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import 'auth_widgets.dart';

/// Pide el código de 6 dígitos enviado a [correo] y lo valida con la API.
/// Devuelve la verificación o null si el usuario cierra la ventana.
Future<VerificacionCorreo?> mostrarModalCodigo(
  BuildContext context, {
  required String correo,
  required int reenviarEn,
}) {
  return showDialog<VerificacionCorreo>(
    context: context,
    barrierDismissible: false,
    barrierColor: const Color(0xB3000000),
    builder: (_) => _ModalCodigo(correo: correo, reenviarEn: reenviarEn),
  );
}

class _ModalCodigo extends StatefulWidget {
  final String correo;
  final int reenviarEn;
  const _ModalCodigo({required this.correo, required this.reenviarEn});

  @override
  State<_ModalCodigo> createState() => _ModalCodigoState();
}

class _ModalCodigoState extends State<_ModalCodigo> {
  static const _largo = 6;
  final _codigo = TextEditingController();
  final _focus = FocusNode();
  Timer? _timer;
  late int _espera = widget.reenviarEn;
  bool _verificando = false;
  bool _reenviando = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _iniciarEspera();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codigo.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _iniciarEspera() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_espera <= 1) t.cancel();
      setState(() => _espera = _espera > 0 ? _espera - 1 : 0);
    });
  }

  Future<void> _verificar() async {
    if (_verificando || _codigo.text.length != _largo) return;
    setState(() {
      _verificando = true;
      _error = null;
    });
    try {
      final r = await AuthRepository.instance.verificarCodigo(
        widget.correo,
        _codigo.text,
      );
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _verificando = false;
        _error = e.mensaje;
        _codigo.clear();
      });
      _focus.requestFocus();
    }
  }

  Future<void> _reenviar() async {
    if (_espera > 0 || _reenviando) return;
    setState(() {
      _reenviando = true;
      _error = null;
    });
    try {
      final espera = await AuthRepository.instance.enviarCodigo(widget.correo);
      if (!mounted) return;
      setState(() {
        _espera = espera;
        _codigo.clear();
      });
      _iniciarEspera();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _reenviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 380),
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borde2),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Revisa tu correo', style: AppText.serif(26)),
                const SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    style: AppText.poppins(
                      13.2,
                      color: AppColors.texto2,
                      height: 1.5,
                    ),
                    children: [
                      const TextSpan(
                        text: 'Escribe el código de 6 dígitos que enviamos a ',
                      ),
                      TextSpan(
                        text: widget.correo,
                        style: AppText.poppins(
                          13.2,
                          weight: FontWeight.w600,
                          color: AppColors.texto,
                          height: 1.5,
                        ),
                      ),
                      const TextSpan(
                        text: '. Si no lo ves, busca en correo no deseado.',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _CeldasCodigo(
                  controller: _codigo,
                  focusNode: _focus,
                  largo: _largo,
                  error: _error != null,
                  enabled: !_verificando,
                  onCompleto: _verificar,
                  onCambio: () => setState(() => _error = null),
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 180),
                  child: _error == null
                      ? const SizedBox(height: 18)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10, bottom: 4),
                          child: Text(
                            _error!,
                            style: AppText.poppins(
                              12.5,
                              color: AppColors.error,
                            ),
                          ),
                        ),
                ),
                AuthPrimaryButton(
                  label: _verificando ? 'Verificando...' : 'Verificar correo',
                  onTap: _verificando || _codigo.text.length != _largo
                      ? null
                      : _verificar,
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _verificando
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.texto2,
                      ),
                      child: Text(
                        'Cambiar correo',
                        style: AppText.poppins(12.8, color: AppColors.texto2),
                      ),
                    ),
                    TextButton(
                      onPressed: _espera > 0 || _reenviando || _verificando
                          ? null
                          : _reenviar,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                      ),
                      child: Text(
                        _reenviando
                            ? 'Enviando...'
                            : _espera > 0
                            ? 'Reenviar en ${_espera}s'
                            : 'Reenviar código',
                        style: AppText.poppins(
                          12.8,
                          weight: FontWeight.w600,
                          color: _espera > 0
                              ? AppColors.texto3
                              : AppColors.teal,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Seis casillas sobre un único campo invisible: admite pegar el código
/// completo y el autocompletado de códigos del teclado.
class _CeldasCodigo extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int largo;
  final bool error;
  final bool enabled;
  final VoidCallback onCompleto;
  final VoidCallback onCambio;

  const _CeldasCodigo({
    required this.controller,
    required this.focusNode,
    required this.largo,
    required this.error,
    required this.enabled,
    required this.onCompleto,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Campo real, invisible: recibe teclado, pegado y autocompletado.
        Positioned.fill(
          child: Opacity(
            opacity: 0,
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              autofocus: true,
              enabled: enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: largo,
              showCursor: false,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                counterText: '',
                border: InputBorder.none,
              ),
              onChanged: (v) {
                onCambio();
                if (v.length == largo) onCompleto();
              },
            ),
          ),
        ),
        IgnorePointer(
          child: ListenableBuilder(
            listenable: Listenable.merge([controller, focusNode]),
            builder: (context, _) {
              final texto = controller.text;
              return Row(
                children: [
                  for (var i = 0; i < largo; i++) ...[
                    if (i > 0) SizedBox(width: i == largo ~/ 2 ? 14 : 8),
                    Expanded(child: _celda(i, texto)),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _celda(int i, String texto) {
    final activa = focusNode.hasFocus && i == texto.length.clamp(0, largo - 1);
    final llena = i < texto.length;
    final color = error
        ? AppColors.error
        : activa
        ? AppColors.teal
        : llena
        ? AppColors.borde2
        : AppColors.borde;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: activa ? AppColors.bg3 : AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color, width: activa ? 2 : 1.5),
      ),
      child: Text(
        llena ? texto[i] : '',
        style: AppText.serif(28, color: AppColors.texto),
      ),
    );
  }
}
