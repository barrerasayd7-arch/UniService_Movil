import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../../widgets/google_g_logo.dart';

// ─────────────────────────────────────────────────────────────
// Campo de texto (.campo + .campo-label + input + .error-msg)
// ─────────────────────────────────────────────────────────────
class AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final bool obscure;
  final TextInputType keyboardType;
  final String? errorText;
  final bool enabled;
  final bool verified;

  /// Widget a la derecha del input (botón "Enviar código" / badge "Verificado").
  final Widget? trailing;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.errorText,
    this.enabled = true,
    this.verified = false,
    this.trailing,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    final borderColor = widget.verified
        ? AppColors.verificado
        : focused
            ? AppColors.teal
            : AppColors.borde;

    final input = AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        color: focused ? AppColors.bg3 : AppColors.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: focused
            ? [
                BoxShadow(
                  color: AppColors.a(AppColors.teal, 0.12),
                  spreadRadius: 3,
                  blurRadius: 0,
                ),
              ]
            : const [],
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        obscureText: widget.obscure,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        cursorColor: AppColors.teal,
        style: AppText.poppins(
          13.76,
          color: widget.verified ? AppColors.texto2 : AppColors.texto,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          hintText: widget.hint,
          hintStyle: AppText.poppins(13.76, color: const Color(0xFF1E3D5C)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5),
            child: Text(
              widget.label.toUpperCase(),
              style: AppText.poppins(
                11.84,
                weight: FontWeight.w700,
                color: AppColors.texto2,
                spacing: 1.2,
              ),
            ),
          ),
          if (widget.trailing == null)
            input
          else
            Row(
              children: [
                Expanded(child: input),
                const SizedBox(width: 8),
                widget.trailing!,
              ],
            ),
          if (widget.errorText != null && widget.errorText!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                widget.errorText!,
                style: AppText.poppins(12, color: AppColors.error),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Tabs "Iniciar sesión" / "Registrarse" (.tabs)
// ─────────────────────────────────────────────────────────────
class AuthTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const AuthTabs({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, int i) {
      final activo = index == i;
      return Expanded(
        child: GestureDetector(
          onTap: () => onChanged(i),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(vertical: 8),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: activo ? AppColors.teal : Colors.transparent,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Text(
                label,
                style: AppText.poppins(
                  12.96,
                  weight: activo ? FontWeight.w700 : FontWeight.w600,
                  color: activo ? AppColors.bg : AppColors.texto2,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border.all(color: AppColors.borde),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          tab('Iniciar sesión', 0),
          const SizedBox(width: 4),
          tab('Registrarse', 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Botón principal (.btn-principal)
// ─────────────────────────────────────────────────────────────
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  const AuthPrimaryButton({super.key, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onTap == null;
    return HoverBuilder(
      builder: (context, hover) {
        final h = hover && !deshabilitado;
        return GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            transform: Matrix4.translationValues(0, h ? -2 : 0, 0),
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (h ? AppColors.teal2 : AppColors.teal)
                  .withAlpha(deshabilitado ? 150 : 255),
              border: Border.all(color: AppColors.teal2),
              borderRadius: BorderRadius.circular(10),
              boxShadow: h
                  ? [
                      BoxShadow(
                        color: AppColors.a(AppColors.teal, 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : const [],
            ),
            child: Text(
              label,
              style: AppText.poppins(
                14.08,
                weight: FontWeight.w700,
                color: AppColors.bg,
                spacing: 0.5,
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Botón secundario (.btn-secundario)
// ─────────────────────────────────────────────────────────────
class AuthSecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const AuthSecondaryButton({super.key, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, hover ? -1 : 0, 0),
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.a(AppColors.teal, hover ? 0.14 : 0.08),
            border: Border.all(color: AppColors.a(AppColors.teal, 0.3)),
            borderRadius: BorderRadius.circular(10),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            label,
            style: AppText.poppins(
              14.08,
              weight: FontWeight.w700,
              color: AppColors.teal,
              spacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Botón "Continuar con Google" (aspecto del GoogleLogin outline)
// ─────────────────────────────────────────────────────────────
class GoogleButton extends StatelessWidget {
  final VoidCallback onTap;
  const GoogleButton({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 40,
          width: double.infinity,
          decoration: BoxDecoration(
            color: hover ? const Color(0xFFF7FAFF) : Colors.white,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: const Color(0xFFDADCE0)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleGLogo(size: 18),
              const SizedBox(width: 10),
              Text(
                'Continuar con Google',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF3C4043),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Separador "o continúa con" (.separator)
// ─────────────────────────────────────────────────────────────
class AuthSeparator extends StatelessWidget {
  final String text;
  const AuthSeparator({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    Widget linea() => Expanded(
          child: Container(
            height: 1,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, AppColors.borde, Colors.transparent],
              ),
            ),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 14),
      child: Row(
        children: [
          linea(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Opacity(
              opacity: 0.7,
              child: Text(
                text,
                style: AppText.poppins(
                  11.52,
                  weight: FontWeight.w500,
                  color: const Color(0xFF5A7A9A),
                  spacing: 0.5,
                ),
              ),
            ),
          ),
          linea(),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Texto con link: "¿No tienes cuenta? Regístrate gratis" (.pie)
// ─────────────────────────────────────────────────────────────
class AuthPie extends StatelessWidget {
  final String texto;
  final String link;
  final VoidCallback onTap;
  const AuthPie({super.key, required this.texto, required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$texto ',
          textAlign: TextAlign.center,
          style: AppText.poppins(12.64, color: AppColors.texto2),
        ),
        GestureDetector(
          onTap: onTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Text(
              link,
              style: AppText.poppins(
                12.64,
                weight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Modal de notificación (.modal-box error / success)
// ─────────────────────────────────────────────────────────────
Future<void> mostrarNotificacion(
  BuildContext context,
  String mensaje, {
  bool exito = false,
}) {
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 300,
          padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 25),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(12),
            border: Border(
              left: BorderSide(
                color: exito ? const Color(0xFF00C851) : const Color(0xFFFF4D4F),
                width: 5,
              ),
              top: const BorderSide(color: AppColors.borde2),
              right: const BorderSide(color: AppColors.borde2),
              bottom: const BorderSide(color: AppColors.borde2),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: AppText.poppins(14, color: Colors.white),
              ),
              const SizedBox(height: 15),
              GestureDetector(
                onTap: () => Navigator.of(ctx).pop(),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Cerrar',
                    style: AppText.poppins(
                      14,
                      weight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Validaciones iguales a las de InicioSesion.jsx
final RegExp regexCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
