import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/usuarios_mock.dart';
import '../../models/servicio.dart';
import '../../models/usuario.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'profile_widgets.dart';

// ═════════════════════════════════════════════════════════════
// Base: overlay oscuro con blur + caja .image-menu
// ═════════════════════════════════════════════════════════════
Future<T?> mostrarImageMenu<T>(
  BuildContext context, {
  required String titulo,
  IconData? icono,
  String? emoji,
  double maxWidth = 400,
  required Widget Function(BuildContext ctx) builder,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar',
    barrierColor: const Color(0xBF000000),
    transitionDuration: const Duration(milliseconds: 350),
    transitionBuilder: (ctx, anim, _, child) {
      final c = CurvedAnimation(parent: anim, curve: const Cubic(0.16, 1, 0.3, 1));
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero).animate(c),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, __) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: MediaQuery.of(ctx).size.height * 0.85),
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(128),
                    blurRadius: 80,
                    offset: const Offset(0, 25),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    color: AppColors.bg2,
                    padding: const EdgeInsets.fromLTRB(25, 20, 25, 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (icono != null) ...[
                          Icon(icono, size: 21, color: AppColors.teal),
                          const SizedBox(width: 10),
                        ],
                        if (emoji != null) ...[
                          Text(emoji, style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 10),
                        ],
                        Flexible(
                          child: Text(
                            titulo,
                            textAlign: TextAlign.center,
                            style: AppText.poppins(20.8, weight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(25),
                      child: builder(ctx),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// `.image-option`: tarjeta grande con icono cuadrado y texto.
class ImageOption extends StatelessWidget {
  final IconData icono;
  final String texto;
  final VoidCallback? onTap;
  final bool peligro;
  final bool centrado;
  const ImageOption({
    super.key,
    required this.icono,
    required this.texto,
    required this.onTap,
    this.peligro = false,
    this.centrado = false,
  });

  @override
  Widget build(BuildContext context) {
    return HoverBuilder(
      builder: (context, hover) {
        final h = hover && onTap != null;
        return GestureDetector(
          onTap: onTap,
          child: Opacity(
            opacity: onTap == null ? 0.5 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.translationValues(h ? 5 : 0, 0, 0),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: h ? AppColors.tealDim : AppColors.bg2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: h
                      ? AppColors.teal
                      : (peligro ? AppColors.a(const Color(0xFFEF4444), 0.3) : AppColors.borde),
                ),
              ),
              child: Row(
                mainAxisAlignment: centrado ? MainAxisAlignment.center : MainAxisAlignment.start,
                children: [
                  AnimatedScale(
                    duration: const Duration(milliseconds: 250),
                    scale: h ? 1.1 : 1,
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: h ? AppColors.teal : AppColors.bg3,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icono, size: 30, color: h ? AppColors.bg : AppColors.texto),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: Text(
                      texto,
                      style: AppText.poppins(
                        15,
                        weight: FontWeight.w700,
                        color: peligro ? const Color(0xFFF87171) : AppColors.texto,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Campo de texto sencillo de los formularios dentro de los modales.
class _CampoModal extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final bool obscure;
  final TextInputType tipo;
  final int lineas;
  const _CampoModal({
    required this.label,
    required this.controller,
    this.hint = '',
    this.obscure = false,
    this.tipo = TextInputType.text,
    this.lineas = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.poppins(13.6, color: AppColors.texto2)),
          const SizedBox(height: 5),
          TextField(
            controller: controller,
            obscureText: obscure,
            keyboardType: tipo,
            minLines: lineas,
            maxLines: obscure ? 1 : lineas,
            cursorColor: AppColors.teal,
            style: AppText.poppins(14.4),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AppText.poppins(14.4, color: AppColors.texto3),
              filled: true,
              fillColor: const Color(0x0DFFFFFF),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: Color(0x26FFFFFF)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: const BorderSide(color: AppColors.teal),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo pequeño que pide un valor (reemplaza a `prompt()` de la web).
Future<String?> _pedirValor(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String inicial = '',
}) {
  final ctrl = TextEditingController(text: inicial);
  return mostrarImageMenu<String>(
    context,
    titulo: titulo,
    icono: Icons.edit_outlined,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampoModal(label: etiqueta, controller: ctrl),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: ImageOption(
                icono: Icons.arrow_back,
                texto: 'Cancelar',
                centrado: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ImageOption(
                icono: Icons.check,
                texto: 'Guardar',
                centrado: true,
                onTap: () => Navigator.of(ctx).pop(ctrl.text.trim()),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// Editar perfil
// ═════════════════════════════════════════════════════════════
Future<void> mostrarEditarPerfil(BuildContext context, Usuario u) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Editar Perfil',
    icono: Icons.edit_outlined,
    builder: (ctx) {
      Future<void> campo(String titulo, String etiqueta, String inicial) async {
        final v = await _pedirValor(ctx, titulo: titulo, etiqueta: etiqueta, inicial: inicial);
        if (v != null && v.isNotEmpty && ctx.mounted) {
          //  PUT /api/users/{id} con el campo modificado
          mostrarNotificacion(ctx, 'Aquí se guardaría: $v', exito: true);
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageOption(
            icono: Icons.edit_outlined,
            texto: 'Cambiar Nombre',
            onTap: () => campo('Cambiar Nombre', 'Nuevo nombre', u.nombre),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.menu_book_outlined,
            texto: 'Cambiar Descripción',
            onTap: () => campo('Cambiar Descripción', 'Nueva descripción', u.descripcion),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.apartment,
            texto: 'Cambiar Universidad',
            onTap: () => campo('Cambiar Universidad', 'Nueva universidad', u.universidad),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.phone_outlined,
            texto: 'Cambiar Teléfono',
            onTap: () => campo('Cambiar Teléfono', 'Nuevo número de teléfono', u.telefono),
          ),
        ],
      );
    },
  );
}

// ═════════════════════════════════════════════════════════════
// Cambiar avatar
// ═════════════════════════════════════════════════════════════
Future<void> mostrarCambiarAvatar(BuildContext context) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Cambiar Avatar',
    emoji: '📸',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageOption(
          icono: Icons.public,
          texto: 'Usar URL',
          onTap: () async {
            final v = await _pedirValor(ctx, titulo: 'URL de la imagen', etiqueta: 'URL de la imagen');
            if (v != null && v.isNotEmpty && ctx.mounted) {
              //  PUT /api/users/{id} { avatar: url }
              mostrarNotificacion(ctx, 'Aquí se guardaría la URL del avatar.', exito: true);
            }
          },
        ),
        const SizedBox(height: 14),
        ImageOption(
          icono: Icons.folder_outlined,
          texto: 'Subir Imagen',
          onTap: () {
            //  abrir la galería con el paquete image_picker
            mostrarNotificacion(ctx, 'Aquí se abriría la galería (image_picker).');
          },
        ),
      ],
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// Seguridad (menú -> cambiar contraseña / correo)
// ═════════════════════════════════════════════════════════════
Future<void> mostrarSeguridad(BuildContext context) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Seguridad de la Cuenta',
    icono: Icons.lock_outline,
    builder: (ctx) => const _SeguridadContenido(),
  );
}

class _SeguridadContenido extends StatefulWidget {
  const _SeguridadContenido();

  @override
  State<_SeguridadContenido> createState() => _SeguridadContenidoState();
}

class _SeguridadContenidoState extends State<_SeguridadContenido> {
  String? _paso; // null | password | correo
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();
  final _correo = TextEditingController();
  final _passCorreo = TextEditingController();

  @override
  void dispose() {
    for (final c in [_actual, _nueva, _confirmar, _correo, _passCorreo]) {
      c.dispose();
    }
    super.dispose();
  }

  void _guardarPassword() {
    if (_actual.text.isEmpty || _nueva.text.isEmpty || _confirmar.text.isEmpty) {
      mostrarNotificacion(context, 'Completa todos los campos');
    } else if (_nueva.text.length < 8) {
      mostrarNotificacion(context, 'La nueva contraseña debe tener mínimo 8 caracteres');
    } else if (_nueva.text != _confirmar.text) {
      mostrarNotificacion(context, 'Las contraseñas no coinciden');
    } else {
      //  PUT /api/users/{id}/password
      mostrarNotificacion(context, 'Aquí se cambiaría la contraseña.', exito: true);
    }
  }

  void _guardarCorreo() {
    if (!regexCorreo.hasMatch(_correo.text)) {
      mostrarNotificacion(context, 'Ingresa un correo válido');
    } else if (_passCorreo.text.isEmpty) {
      mostrarNotificacion(context, 'Ingresa tu contraseña actual');
    } else {
      //  PUT /api/users/{id}/email
      mostrarNotificacion(context, 'Aquí se cambiaría el correo.', exito: true);
    }
  }

  Widget _botonesPaso(VoidCallback guardar) {
    return Row(
      children: [
        Expanded(
          child: ImageOption(
            icono: Icons.arrow_back,
            texto: 'Volver',
            centrado: true,
            onTap: () => setState(() => _paso = null),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ImageOption(
            icono: Icons.check,
            texto: 'Guardar',
            centrado: true,
            onTap: guardar,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_paso == 'password') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CampoModal(label: 'Contraseña actual', hint: '••••••••', controller: _actual, obscure: true),
          _CampoModal(label: 'Nueva contraseña', hint: 'Mínimo 8 caracteres', controller: _nueva, obscure: true),
          _CampoModal(
            label: 'Confirmar nueva contraseña',
            hint: 'Repite la nueva contraseña',
            controller: _confirmar,
            obscure: true,
          ),
          const SizedBox(height: 4),
          _botonesPaso(_guardarPassword),
        ],
      );
    }
    if (_paso == 'correo') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CampoModal(
            label: 'Nuevo correo electrónico',
            hint: 'nuevo@correo.com',
            controller: _correo,
            tipo: TextInputType.emailAddress,
          ),
          _CampoModal(
            label: 'Contraseña actual (para confirmar)',
            hint: '••••••••',
            controller: _passCorreo,
            obscure: true,
          ),
          const SizedBox(height: 4),
          _botonesPaso(_guardarCorreo),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageOption(
          icono: Icons.key,
          texto: 'Cambiar Contraseña',
          onTap: () => setState(() => _paso = 'password'),
        ),
        const SizedBox(height: 14),
        ImageOption(
          icono: Icons.mail_outline,
          texto: 'Cambiar Correo Electrónico',
          onTap: () => setState(() => _paso = 'correo'),
        ),
      ],
    );
  }
}

final RegExp regexCorreo = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

// ═════════════════════════════════════════════════════════════
// Mis servicios (lista con acciones) + editar / eliminar / imágenes
// ═════════════════════════════════════════════════════════════
Future<void> mostrarMisServicios(BuildContext context, List<Servicio> servicios) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Mis servicios (${servicios.length})',
    icono: Icons.inventory_2,
    maxWidth: 624,
    builder: (ctx) {
      if (servicios.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Aún no has publicado ningún servicio.',
            style: AppText.poppins(13.6, color: AppColors.texto2),
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in servicios)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MenuItem(
                icono: iconosPorCategoria[s.categoria] ?? iconoPorDefecto,
                title: s.titulo,
                desc: '\$${s.precioHora}/hr · ${s.categoria}',
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _BtnCuadrado(Icons.image_outlined, 'Gestionar imágenes',
                        () => mostrarImagenesServicio(ctx, s)),
                    const SizedBox(width: 8),
                    _BtnCuadrado(Icons.edit_outlined, 'Editar', () => mostrarEditarServicio(ctx, s)),
                    const SizedBox(width: 8),
                    _BtnCuadrado(Icons.delete_outline, 'Eliminar', () => mostrarConfirmarEliminar(ctx)),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}

class _BtnCuadrado extends StatelessWidget {
  final IconData icono;
  final String tooltip;
  final VoidCallback onTap;
  const _BtnCuadrado(this.icono, this.tooltip, this.onTap);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: HoverBuilder(
        builder: (context, hover) => GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: hover ? AppColors.teal2 : AppColors.teal,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icono, size: 16, color: AppColors.bg),
          ),
        ),
      ),
    );
  }
}

Future<void> mostrarEditarServicio(BuildContext context, Servicio s) {
  final titulo = TextEditingController(text: s.titulo);
  final precio = TextEditingController(text: '${s.precioHora}');
  final contacto = TextEditingController();
  final descripcion = TextEditingController(text: s.descripcion);
  return mostrarImageMenu<void>(
    context,
    titulo: 'Editar servicio',
    icono: Icons.edit_outlined,
    maxWidth: 500,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _CampoModal(label: 'Título', controller: titulo),
        _CampoModal(label: 'Precio/hora', controller: precio, tipo: TextInputType.number),
        _CampoModal(label: 'Contacto', controller: contacto),
        _CampoModal(label: 'Descripción', controller: descripcion, lineas: 4),
        Row(
          children: [
            Expanded(
              child: ImageOption(
                icono: Icons.arrow_back,
                texto: 'Cancelar',
                centrado: true,
                onTap: () => Navigator.of(ctx).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ImageOption(
                icono: Icons.save_outlined,
                texto: 'Guardar',
                centrado: true,
                onTap: () {
                  //  PUT /api/services/{id}
                  Navigator.of(ctx).pop();
                  mostrarNotificacion(context, 'Aquí se guardarían los cambios.', exito: true);
                },
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

Future<void> mostrarConfirmarEliminar(BuildContext context) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Eliminar servicio',
    icono: Icons.delete_outline,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Text(
            '¿Estás seguro? Esto eliminará también todas las solicitudes asociadas y no se puede deshacer.',
            style: AppText.poppins(14, color: AppColors.texto.withAlpha(179), height: 1.5),
          ),
        ),
        ImageOption(
          icono: Icons.undo,
          texto: 'Cancelar',
          onTap: () => Navigator.of(ctx).pop(),
        ),
        const SizedBox(height: 14),
        ImageOption(
          icono: Icons.delete_outline,
          texto: 'Sí, eliminar',
          peligro: true,
          onTap: () {
            //  DELETE /api/services/{id}
            Navigator.of(ctx).pop();
            mostrarNotificacion(context, 'Aquí se eliminaría el servicio.');
          },
        ),
      ],
    ),
  );
}

Future<void> mostrarImagenesServicio(BuildContext context, Servicio s) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Imágenes de "${s.titulo}"',
    icono: Icons.photo_library_outlined,
    maxWidth: 550,
    builder: (ctx) => _ImagenesContenido(servicio: s),
  );
}

class _ImagenesContenido extends StatefulWidget {
  final Servicio servicio;
  const _ImagenesContenido({required this.servicio});

  @override
  State<_ImagenesContenido> createState() => _ImagenesContenidoState();
}

class _ImagenesContenidoState extends State<_ImagenesContenido> {
  // Marcadores de ejemplo (en la web son imágenes subidas por el usuario)
  final List<int> _imgs = [1, 2, 3];

  void _mover(int i, int d) {
    setState(() {
      final x = _imgs.removeAt(i);
      _imgs.insert(i + d, x);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text(
            '${_imgs.length}/5 — Usa ↑↓ para cambiar el orden. La primera es la portada.',
            style: AppText.poppins(13.6, color: AppColors.texto.withAlpha(153)),
          ),
        ),
        if (_imgs.isEmpty)
          Padding(
            padding: const EdgeInsets.all(20),
            child: Text(
              'No hay imágenes. ¡Agrega una!',
              textAlign: TextAlign.center,
              style: AppText.poppins(14, color: AppColors.texto.withAlpha(128)),
            ),
          )
        else
          for (var i = 0; i < _imgs.length; i++)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: i == 0 ? const Color(0x1434D399) : const Color(0x08FFFFFF),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: i == 0 ? const Color(0x4D34D399) : const Color(0x14FFFFFF),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: i == 0 ? const Color(0xFF34D399) : const Color(0x1AFFFFFF),
                    ),
                    child: Text(
                      '${i + 1}',
                      style: AppText.poppins(
                        12,
                        weight: FontWeight.w700,
                        color: i == 0 ? Colors.black : AppColors.texto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.bg3,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.image_outlined, color: AppColors.texto3),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (i == 0)
                          Text('⭐ Portada', style: AppText.poppins(12.8, weight: FontWeight.w700)),
                        Text(
                          'Click para ver imagen',
                          style: AppText.poppins(11.2, color: AppColors.texto.withAlpha(128))
                              .copyWith(decoration: TextDecoration.underline),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _FlechaOrden('↑', i == 0 ? null : () => _mover(i, -1)),
                      const SizedBox(height: 2),
                      _FlechaOrden('↓', i == _imgs.length - 1 ? null : () => _mover(i, 1)),
                    ],
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => setState(() => _imgs.removeAt(i)),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0x26EF4444),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0x4DEF4444)),
                      ),
                      child: const Icon(Icons.delete_outline, size: 16, color: Color(0xFFF87171)),
                    ),
                  ),
                ],
              ),
            ),
        if (_imgs.length < 5)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 4),
            child: GestureDetector(
              onTap: () => mostrarNotificacion(context, 'Aquí se abriría la galería (image_picker).'),
              child: Opacity(
                opacity: 0.6,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0x26FFFFFF), width: 2),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 16, color: AppColors.texto),
                      const SizedBox(width: 8),
                      Text('Agregar imágenes', style: AppText.poppins(13.6)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        Row(
          children: [
            Expanded(
              child: ImageOption(
                icono: Icons.arrow_back,
                texto: 'Cancelar',
                centrado: true,
                onTap: () => Navigator.of(context).pop(),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: ImageOption(
                icono: Icons.save_outlined,
                texto: 'Guardar orden',
                centrado: true,
                onTap: _imgs.isEmpty
                    ? null
                    : () {
                        //PUT orden de imágenes 
                        Navigator.of(context).pop();
                      },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FlechaOrden extends StatelessWidget {
  final String texto;
  final VoidCallback? onTap;
  const _FlechaOrden(this.texto, this.onTap);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: const Color(0x26FFFFFF)),
        ),
        child: Text(
          texto,
          style: AppText.poppins(
            11.2,
            color: onTap == null ? const Color(0x33FFFFFF) : AppColors.texto,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Lista de seguidores / siguiendo
// ═════════════════════════════════════════════════════════════
Future<void> mostrarListaPersonas(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  required List<PersonaLista> personas,
  required String vacio,
  required void Function(PersonaLista) onTapPersona,
}) {
  return mostrarImageMenu<void>(
    context,
    titulo: '$titulo (${personas.length})',
    icono: icono,
    builder: (ctx) {
      if (personas.isEmpty) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            vacio,
            textAlign: TextAlign.center,
            style: AppText.poppins(14, color: AppColors.texto2),
          ),
        );
      }
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final p in personas)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: MenuItem(
                icono: Icons.person,
                title: p.nombre,
                desc: p.universidad,
                leading: ClipOval(
                  child: Image.asset(
                    'assets/img/default-avatar.png',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                  ),
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  onTapPersona(p);
                },
              ),
            ),
        ],
      );
    },
  );
}
