// Archivo: auth_widgets.dart
// Responsabilidad: piezas compartidas de los formularios de acceso (campo, pestañas, botones, avisos y validaciones).
// Se usa desde: login_form, register_form, recuperar_password y modal_codigo.

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;

// ─────────────────────────────────────────────────────────────
// Campo de texto: etiqueta, campo con ícono y error debajo.
// ─────────────────────────────────────────────────────────────
/// Campo reutilizable de los formularios de acceso: etiqueta, borde según foco
/// o error, y botón de mostrar/ocultar cuando [obscure] está activo.
class AuthField extends StatefulWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool obscure; // contraseña: añade el botón de mostrar/ocultar
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final IconData? icon;
  final String? errorText;
  final bool enabled;
  final Widget? trailing;

  const AuthField({
    super.key,
    required this.label,
    required this.hint,
    required this.controller,
    this.onChanged,
    this.onSubmitted,
    this.obscure = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.autofillHints,
    this.icon,
    this.errorText,
    this.enabled = true,
    this.trailing,
  });

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  final FocusNode _focus = FocusNode();
  bool _oculto = true;

  bool get _hayError =>
      widget.errorText != null && widget.errorText!.isNotEmpty;

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
    final borde = _hayError
        ? AppColors.errorTexto
        : focused
        ? AppColors.teal
        : AppColors.bordeCampo;
    final colorIcono = focused ? AppColors.teal : AppColors.placeholder;

    final input = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: focused ? AppColors.bg3 : AppColors.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borde, width: focused ? 1.6 : 1.2),
      ),
      child: TextField(
        controller: widget.controller,
        focusNode: _focus,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
        obscureText: widget.obscure && _oculto,
        enabled: widget.enabled,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        autofillHints: widget.autofillHints,
        autocorrect:
            !widget.obscure &&
            widget.keyboardType != TextInputType.emailAddress,
        enableSuggestions: !widget.obscure,
        cursorColor: AppColors.teal,
        style: AppText.poppins(
          15,
          color: widget.enabled ? AppColors.texto : AppColors.texto2,
        ),
        decoration: InputDecoration(
          isDense: true,
          border: InputBorder.none,
          hintText: widget.hint,
          hintStyle: AppText.poppins(15, color: AppColors.placeholder),
          contentPadding: EdgeInsets.fromLTRB(
            widget.icon == null ? 14 : 0,
            14,
            14,
            14,
          ),
          prefixIcon: widget.icon == null
              ? null
              : Icon(widget.icon, size: 20, color: colorIcono),
          prefixIconConstraints: const BoxConstraints(
            minWidth: 46,
            minHeight: 48,
          ),
          suffixIcon: widget.obscure
              ? IconButton(
                  tooltip: _oculto
                      ? 'Mostrar contraseña'
                      : 'Ocultar contraseña',
                  onPressed: () => setState(() => _oculto = !_oculto),
                  icon: Icon(
                    _oculto
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                    color: AppColors.placeholder,
                  ),
                )
              : null,
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 6, left: 2),
            child: Text(
              widget.label,
              style: AppText.poppins(
                13,
                weight: FontWeight.w500,
                color: AppColors.texto2,
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
          if (_hayError)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 2),
              child: Text(
                widget.errorText!,
                style: AppText.poppins(12.5, color: AppColors.errorTexto),
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Selector "Iniciar sesión" / "Crear cuenta" (control segmentado)
// ─────────────────────────────────────────────────────────────
/// Selector segmentado entre "Iniciar sesión" (0) y "Crear cuenta" (1).
/// [onChanged] recibe el índice de la pestaña tocada.
class AuthTabs extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  const AuthTabs({super.key, required this.index, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget tab(String label, int i) {
      final activo = index == i;
      return Expanded(
        child: Semantics(
          button: true,
          selected: activo,
          child: GestureDetector(
            onTap: () => onChanged(i),
            behavior: HitTestBehavior.opaque,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: activo ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  label,
                  style: AppText.poppins(
                    14,
                    weight: FontWeight.w600,
                    color: activo ? AppColors.bg : AppColors.texto2,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: AppColors.bg2,
        border: Border.all(color: AppColors.borde),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          tab('Iniciar sesión', 0),
          const SizedBox(width: 4),
          tab('Crear cuenta', 1),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Botón principal (acción del formulario)
// ─────────────────────────────────────────────────────────────
/// Botón principal del formulario; muestra un indicador mientras [cargando].
/// [color] y [colorHover] permiten variantes como el acceso de administrador.
class AuthPrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool cargando;

  /// Fondo del botón (teal por defecto; ámbar en el acceso de administrador).
  final Color color;
  final Color colorHover;
  const AuthPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.cargando = false,
    this.color = AppColors.teal,
    this.colorHover = AppColors.teal2,
  });

  @override
  Widget build(BuildContext context) {
    final deshabilitado = onTap == null || cargando;
    return Semantics(
      button: true,
      enabled: !deshabilitado,
      child: HoverBuilder(
        builder: (context, hover) {
          final h = hover && !deshabilitado;
          return GestureDetector(
            onTap: deshabilitado ? null : onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 50,
              width: double.infinity,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: (h ? colorHover : color).withAlpha(
                  deshabilitado && !cargando ? 140 : 255,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: h
                    ? [
                        BoxShadow(
                          color: AppColors.a(color, 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: cargando
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.bg,
                      ),
                    )
                  : Text(
                      label,
                      style: AppText.poppins(
                        15,
                        weight: FontWeight.w700,
                        color: AppColors.bg,
                      ),
                    ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Acción secundaria de bajo énfasis (texto en teal)
// ─────────────────────────────────────────────────────────────
/// Acción secundaria de bajo énfasis (texto en teal) con área táctil mínima de 44 px.
class AuthTextButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Color color;
  const AuthTextButton({
    super.key,
    required this.label,
    this.onTap,
    this.color = AppColors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        minimumSize: const Size(48, 44),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        tapTargetSize: MaterialTapTargetSize.padded,
      ),
      child: Text(
        label,
        style: AppText.poppins(14, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Aviso dentro del formulario (errores de la API, junto a la acción)
// ─────────────────────────────────────────────────────────────
/// Aviso dentro del formulario para errores de la API o confirmaciones.
/// Con [exito] cambia a verde; con [mensaje] nulo no ocupa espacio.
class AuthAviso extends StatelessWidget {
  final String? mensaje;
  final bool exito;
  const AuthAviso({super.key, required this.mensaje, this.exito = false});

  @override
  Widget build(BuildContext context) {
    final color = exito ? AppColors.verificado : AppColors.errorTexto;
    return AnimatedSize(
      duration: const Duration(milliseconds: 180),
      alignment: Alignment.topCenter,
      child: mensaje == null
          ? const SizedBox(width: double.infinity)
          : Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: AppColors.a(color, 0.08),
                  border: Border.all(color: AppColors.a(color, 0.35)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      exito ? Icons.check_circle_outline : Icons.error_outline,
                      size: 18,
                      color: color,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        mensaje!,
                        style: AppText.poppins(
                          13,
                          color: AppColors.texto,
                          height: 1.4,
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

// ─────────────────────────────────────────────────────────────
// Ventana de aviso (para confirmaciones fuera de un formulario)
// ─────────────────────────────────────────────────────────────
/// Muestra una ventana modal con un mensaje y el botón "Entendido".
/// Se usa para confirmaciones que no viven dentro de un formulario.
Future<void> mostrarNotificacion(
  BuildContext context,
  String mensaje, {
  bool exito = false,
}) {
  final color = exito ? AppColors.verificado : AppColors.errorTexto;
  return showDialog<void>(
    context: context,
    barrierColor: const Color(0x99000000),
    builder: (ctx) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 12),
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borde2),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                exito ? Icons.check_circle_outline : Icons.info_outline,
                color: color,
                size: 30,
              ),
              const SizedBox(height: 12),
              Text(
                mensaje,
                textAlign: TextAlign.center,
                style: AppText.poppins(
                  14.5,
                  color: AppColors.texto,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 8),
              AuthTextButton(
                label: 'Entendido',
                onTap: () => Navigator.of(ctx).pop(),
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

/// Misma regla que el backend (InstitutionalAccess.NormalizeEmail): sólo @unicesar.edu.co.
final RegExp regexCorreoInstitucional = RegExp(
  r'^[a-z0-9][a-z0-9._+-]*@unicesar\.edu\.co$',
);

String normalizarCorreo(String v) => v.trim().toLowerCase();
