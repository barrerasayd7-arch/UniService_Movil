import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../login/auth_widgets.dart';

/// Avisa que la cuenta entra con privilegios de administrador.
/// Devuelve true si elige ir al panel; false si sigue usando la app como usuario.
Future<bool> mostrarAvisoAdmin(BuildContext context) async {
  final irAlPanel = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => const _AvisoAdmin(),
  );
  return irAlPanel ?? false;
}

class _AvisoAdmin extends StatelessWidget {
  const _AvisoAdmin();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Material(
          color: Colors.transparent,
          child: Semantics(
            scopesRoute: true,
            namesRoute: true,
            label: 'Vas a entrar como administrador',
            child: Container(
              constraints: const BoxConstraints(maxWidth: 360),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.a(AppColors.admin, 0.35)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: _IconoAdmin(tamano: 56)),
                  const SizedBox(height: 16),
                  Text(
                    'Vas a entrar como administrador',
                    textAlign: TextAlign.center,
                    style: AppText.serif(25, height: 1.15),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Podrás suspender cuentas, moderar servicios y responder '
                    'reportes. Cada acción queda registrada a tu nombre.',
                    textAlign: TextAlign.center,
                    style: AppText.poppins(
                      14.5,
                      color: AppColors.texto2,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 22),
                  AuthPrimaryButton(
                    label: 'Continuar al panel',
                    color: AppColors.admin,
                    colorHover: AppColors.adminHover,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: AuthTextButton(
                      label: 'Seguir como usuario',
                      color: AppColors.texto2,
                      onTap: () => Navigator.of(context).pop(false),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Escudo del modo administrador (decorativo: el texto de al lado ya lo nombra).
class _IconoAdmin extends StatelessWidget {
  final double tamano;
  const _IconoAdmin({required this.tamano});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: tamano,
        height: tamano,
        decoration: BoxDecoration(
          color: AppColors.a(AppColors.admin, 0.12),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.a(AppColors.admin, 0.3)),
        ),
        child: Icon(
          Icons.admin_panel_settings_outlined,
          color: AppColors.admin,
          size: tamano * 0.5,
        ),
      ),
    );
  }
}

/// Etiqueta "Modo administrador": marca cada pantalla con privilegios.
class InsigniaAdmin extends StatelessWidget {
  const InsigniaAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: AppColors.a(AppColors.admin, 0.10),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.a(AppColors.admin, 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.admin_panel_settings_outlined,
              size: 16,
              color: AppColors.admin,
            ),
            const SizedBox(width: 6),
            Text(
              'Modo administrador',
              style: AppText.poppins(
                12.5,
                weight: FontWeight.w600,
                color: AppColors.admin,
                spacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Hora local "14:05" para avisos de bloqueo y vencimiento.
String horaCorta(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}

/// Confirmación de una acción del panel. true = confirmó.
Future<bool> confirmarAdmin(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String confirmar = 'Confirmar',
  bool peligro = false,
}) async {
  final r = await showDialog<bool>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (ctx) => AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.a(AppColors.admin, 0.35)),
      ),
      title: Text(titulo, style: AppText.serif(23, height: 1.15)),
      content: Text(
        mensaje,
        style: AppText.poppins(14.5, color: AppColors.texto2, height: 1.5),
      ),
      actions: [
        AuthTextButton(
          label: 'Cancelar',
          color: AppColors.texto2,
          onTap: () => Navigator.of(ctx).pop(false),
        ),
        AuthTextButton(
          label: confirmar,
          color: peligro ? AppColors.errorTexto : AppColors.admin,
          onTap: () => Navigator.of(ctx).pop(true),
        ),
      ],
    ),
  );
  return r == true;
}

/// Pide un texto (motivo de rechazo, notas). null = canceló; '' = lo dejó vacío.
Future<String?> pedirMotivo(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  String hint = '',
  String confirmar = 'Confirmar',
  String? inicial,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: const Color(0xB3000000),
    builder: (_) => _DialogoMotivo(
      titulo: titulo,
      mensaje: mensaje,
      hint: hint,
      confirmar: confirmar,
      inicial: inicial,
    ),
  );
}

class _DialogoMotivo extends StatefulWidget {
  final String titulo, mensaje, hint, confirmar;
  final String? inicial;
  const _DialogoMotivo({
    required this.titulo,
    required this.mensaje,
    required this.hint,
    required this.confirmar,
    this.inicial,
  });

  @override
  State<_DialogoMotivo> createState() => _DialogoMotivoState();
}

class _DialogoMotivoState extends State<_DialogoMotivo> {
  late final _c = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: AppColors.a(AppColors.admin, 0.35)),
      ),
      title: Text(widget.titulo, style: AppText.serif(23, height: 1.15)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.mensaje,
              style: AppText.poppins(
                14.5,
                color: AppColors.texto2,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _c,
              minLines: 3,
              maxLines: 5,
              maxLength: 500,
              cursorColor: AppColors.admin,
              style: AppText.poppins(14.5, height: 1.5),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.bg2,
                hintText: widget.hint,
                hintStyle: AppText.poppins(14.5, color: AppColors.placeholder),
                counterStyle: AppText.poppins(11.5, color: AppColors.texto3),
                enabledBorder: borde(AppColors.bordeCampo),
                focusedBorder: borde(AppColors.admin, 1.6),
              ),
            ),
          ],
        ),
      ),
      actions: [
        AuthTextButton(
          label: 'Cancelar',
          color: AppColors.texto2,
          onTap: () => Navigator.of(context).pop(),
        ),
        AuthTextButton(
          label: widget.confirmar,
          color: AppColors.admin,
          onTap: () => Navigator.of(context).pop(_c.text.trim()),
        ),
      ],
    );
  }
}

/// Etiqueta de estado (Pendiente, Resuelto, Activo…) con el color que se le pase.
class PildoraEstado extends StatelessWidget {
  final String texto;
  final Color color;
  const PildoraEstado({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.a(color, 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.a(color, 0.35)),
      ),
      child: Text(
        texto,
        style: AppText.poppins(12, weight: FontWeight.w600, color: color),
      ),
    );
  }
}
