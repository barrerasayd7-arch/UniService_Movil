// Archivo: profile_modals.dart
// Responsabilidad: modales del perfil (editar datos, avatar, seguridad, listas
//   y reportes) y las piezas compartidas por ellos.
// Se usa desde: profile_screen.dart.

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/api_client.dart';
import '../../data/auth_repository.dart';
import '../../data/perfil_repository.dart';
import '../../models/usuario.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'profile_widgets.dart';
import '../../widgets/avatar_respaldo.dart';

// ═════════════════════════════════════════════════════════════
// Base: overlay oscuro con blur + caja .image-menu
// ═════════════════════════════════════════════════════════════
/// Envoltorio común de los modales: overlay oscuro, caja con cabecera,
/// animación de entrada y cierre por toque fuera. [builder] recibe el
/// contexto del diálogo para poder cerrarlo.
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
      final c = CurvedAnimation(
        parent: anim,
        curve: const Cubic(0.16, 1, 0.3, 1),
      );
      return FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.06),
            end: Offset.zero,
          ).animate(c),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, _, _) => SafeArea(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: double.infinity,
              constraints: BoxConstraints(
                maxWidth: maxWidth,
                maxHeight: MediaQuery.of(ctx).size.height * 0.85,
              ),
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
                            style: AppText.poppins(
                              20.8,
                              weight: FontWeight.w700,
                            ),
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
                      : (peligro
                            ? AppColors.a(const Color(0xFFEF4444), 0.3)
                            : AppColors.borde),
                ),
              ),
              child: Row(
                mainAxisAlignment: centrado
                    ? MainAxisAlignment.center
                    : MainAxisAlignment.start,
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
                      child: Icon(
                        icono,
                        size: 30,
                        color: h ? AppColors.bg : AppColors.texto,
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Flexible(
                    child: Text(
                      texto,
                      style: AppText.poppins(
                        15,
                        weight: FontWeight.w700,
                        color: peligro
                            ? const Color(0xFFF87171)
                            : AppColors.texto,
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
  final int? maxLength;
  const _CampoModal({
    required this.label,
    required this.controller,
    this.hint = '',
    this.obscure = false,
    this.tipo = TextInputType.text,
    this.lineas = 1,
    this.maxLength,
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
            keyboardType: lineas > 1 ? TextInputType.multiline : tipo,
            maxLines: lineas,
            minLines: 1,
            maxLength: maxLength,
            cursorColor: AppColors.teal,
            style: AppText.poppins(14.4),
            decoration: InputDecoration(
              isDense: true,
              hintText: hint,
              hintStyle: AppText.poppins(14.4, color: AppColors.texto3),
              filled: true,
              fillColor: const Color(0x0DFFFFFF),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
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
/// Devuelve null si se cancela; si se guarda, el texto recortado (puede ser vacío).
Future<String?> _pedirValor(
  BuildContext context, {
  required String titulo,
  required String etiqueta,
  String inicial = '',
  String hint = '',
  int lineas = 1,
  int? maxLength,
  TextInputType tipo = TextInputType.text,
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
        _CampoModal(
          label: etiqueta,
          hint: hint,
          controller: ctrl,
          lineas: lineas,
          maxLength: maxLength,
          tipo: tipo,
        ),
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

/// Primer error de campo que devuelve la API ({ error, campos: { nombre: "..." } }).
String _mensaje(ApiException e) {
  final campos = e.datos?['campos'];
  if (campos is Map && campos.isNotEmpty) return '${campos.values.first}';
  return e.mensaje;
}

/// Foto de perfil: la URL del servidor o la imagen por defecto.
Widget fotoPerfil(String? url, {double? size}) {
  final porDefecto = Image.asset(
    'assets/img/default-avatar.png',
    errorBuilder: avatarRespaldo,
    width: size,
    height: size,
    fit: BoxFit.cover,
  );
  if (url == null || url.isEmpty) return porDefecto;
  return Image.network(
    url,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => porDefecto,
  );
}

// ═════════════════════════════════════════════════════════════
// Editar perfil (PUT /api/perfil/me, un campo cada vez)
// ═════════════════════════════════════════════════════════════
/// Editor campo a campo: cada opción abre [_pedirValor] y sólo llama a la API
/// si el valor cambió. [onActualizado] refresca el perfil en pantalla.
Future<void> mostrarEditarPerfil(
  BuildContext context,
  Usuario u, {
  required void Function(Usuario actualizado) onActualizado,
}) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Editar Perfil',
    icono: Icons.edit_outlined,
    builder: (ctx) {
      Future<void> campo(
        String clave,
        String titulo,
        String etiqueta,
        String inicial, {
        String hint = '',
        int lineas = 1,
        int? maxLength,
        TextInputType tipo = TextInputType.text,
      }) async {
        final v = await _pedirValor(
          ctx,
          titulo: titulo,
          etiqueta: etiqueta,
          inicial: inicial,
          hint: hint,
          lineas: lineas,
          maxLength: maxLength,
          tipo: tipo,
        );
        if (v == null || v == inicial || !ctx.mounted) return;
        try {
          final nuevo = await PerfilRepository.instance.actualizar({clave: v});
          onActualizado(nuevo);
          if (ctx.mounted) {
            mostrarNotificacion(ctx, 'Perfil actualizado', exito: true);
          }
        } on ApiException catch (e) {
          if (ctx.mounted) mostrarNotificacion(ctx, _mensaje(e));
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageOption(
            icono: Icons.edit_outlined,
            texto: 'Cambiar Nombre',
            onTap: () => campo(
              'nombre',
              'Cambiar Nombre',
              'Nombre y apellido',
              u.nombre,
              maxLength: 50,
            ),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.menu_book_outlined,
            texto: 'Cambiar Descripción',
            onTap: () => campo(
              'descripcion',
              'Cambiar Descripción',
              'Cuéntales a los demás qué ofreces',
              u.descripcion,
              lineas: 4,
              maxLength: 500,
            ),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.school_outlined,
            texto: 'Programa académico',
            onTap: () => campo(
              'programa',
              'Programa académico',
              'Ej.: Ingeniería de Sistemas',
              u.programa,
              maxLength: 120,
            ),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.phone_outlined,
            texto: 'Cambiar Teléfono',
            onTap: () => campo(
              'telefono',
              'Cambiar Teléfono',
              'Número de teléfono (solo tú lo ves)',
              u.telefono ?? '',
              tipo: TextInputType.phone,
              maxLength: 16,
            ),
          ),
        ],
      );
    },
  );
}

// ═════════════════════════════════════════════════════════════
// Cambiar avatar (POST/DELETE /api/perfil/me/avatar)
// ═════════════════════════════════════════════════════════════
/// Galería o cámara con compresión local; valida el tamaño y delega la subida
/// al repositorio. [onCambio] recibe la URL nueva o null al quitar la foto.
Future<void> mostrarCambiarAvatar(
  BuildContext context, {
  required bool tieneAvatar,
  required void Function(String? url) onCambio,
}) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Cambiar Avatar',
    emoji: '📸',
    builder: (ctx) {
      Future<void> elegir(ImageSource origen) async {
        XFile? foto;
        try {
          // Reducida y recomprimida en el teléfono; el servidor además le quita EXIF/GPS.
          foto = await ImagePicker().pickImage(
            source: origen,
            maxWidth: 1024,
            maxHeight: 1024,
            imageQuality: 85,
          );
        } catch (_) {
          if (ctx.mounted) {
            mostrarNotificacion(ctx, 'No se pudo abrir la cámara o la galería');
          }
          return;
        }
        if (foto == null) return;
        final bytes = await foto.readAsBytes();
        if (bytes.length > 2 * 1024 * 1024) {
          if (ctx.mounted) {
            mostrarNotificacion(ctx, 'La imagen debe pesar menos de 2 MB');
          }
          return;
        }
        try {
          onCambio(await PerfilRepository.instance.subirAvatar(bytes, foto.name));
          if (ctx.mounted) Navigator.of(ctx).pop();
          if (context.mounted) {
            mostrarNotificacion(context, 'Foto actualizada', exito: true);
          }
        } on ApiException catch (e) {
          if (ctx.mounted) mostrarNotificacion(ctx, e.mensaje);
        }
      }

      Future<void> quitar() async {
        try {
          await PerfilRepository.instance.quitarAvatar();
          onCambio(null);
          if (ctx.mounted) Navigator.of(ctx).pop();
        } on ApiException catch (e) {
          if (ctx.mounted) mostrarNotificacion(ctx, e.mensaje);
        }
      }

      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ImageOption(
            icono: Icons.photo_library_outlined,
            texto: 'Elegir de la galería',
            onTap: () => elegir(ImageSource.gallery),
          ),
          const SizedBox(height: 14),
          ImageOption(
            icono: Icons.photo_camera_outlined,
            texto: 'Tomar una foto',
            onTap: () => elegir(ImageSource.camera),
          ),
          if (tieneAvatar) ...[
            const SizedBox(height: 14),
            ImageOption(
              icono: Icons.delete_outline,
              texto: 'Quitar foto',
              peligro: true,
              onTap: quitar,
            ),
          ],
        ],
      );
    },
  );
}

// ═════════════════════════════════════════════════════════════
// Seguridad (cambiar contraseña)
// ═════════════════════════════════════════════════════════════
/// Seguridad de la cuenta: cambiar contraseña o consultar el correo
/// institucional (no editable desde la app).
Future<void> mostrarSeguridad(BuildContext context) {
  return mostrarImageMenu<void>(
    context,
    titulo: 'Seguridad de la Cuenta',
    icono: Icons.lock_outline,
    builder: (ctx) => const _SeguridadContenido(),
  );
}

/// Alterna entre el menú de seguridad y el formulario de cambio de contraseña.
class _SeguridadContenido extends StatefulWidget {
  const _SeguridadContenido();

  @override
  State<_SeguridadContenido> createState() => _SeguridadContenidoState();
}

class _SeguridadContenidoState extends State<_SeguridadContenido> {
  bool _cambiandoPassword = false;
  bool _guardando = false;
  final _actual = TextEditingController();
  final _nueva = TextEditingController();
  final _confirmar = TextEditingController();

  @override
  void dispose() {
    for (final c in [_actual, _nueva, _confirmar]) {
      c.dispose();
    }
    super.dispose();
  }

  // Las mismas reglas que valida el servidor.
  String? _errorNueva(String p) {
    if (p.length < 8) return 'La nueva contraseña debe tener mínimo 8 caracteres';
    if (p.length > 72) return 'La nueva contraseña es demasiado larga';
    if (!p.contains(RegExp(r'\p{L}', unicode: true)) || !p.contains(RegExp(r'\d'))) {
      return 'La nueva contraseña debe combinar letras y números';
    }
    return null;
  }

  Future<void> _guardarPassword() async {
    // Evita un segundo envío mientras la petición anterior sigue en curso.
    if (_guardando) return;
    if (_actual.text.isEmpty || _nueva.text.isEmpty || _confirmar.text.isEmpty) {
      mostrarNotificacion(context, 'Completa todos los campos');
      return;
    }
    final error = _errorNueva(_nueva.text);
    if (error != null) {
      mostrarNotificacion(context, error);
      return;
    }
    if (_nueva.text != _confirmar.text) {
      mostrarNotificacion(context, 'Las contraseñas no coinciden');
      return;
    }
    setState(() => _guardando = true);
    try {
      await AuthRepository.instance.cambiarPassword(_actual.text, _nueva.text);
      if (!mounted) return;
      await mostrarNotificacion(
        context,
        'Contraseña cambiada. Se cerró la sesión en tus otros dispositivos.',
        exito: true,
      );
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cambiandoPassword) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _CampoModal(
            label: 'Contraseña actual',
            hint: '••••••••',
            controller: _actual,
            obscure: true,
          ),
          _CampoModal(
            label: 'Nueva contraseña',
            hint: 'Mínimo 8 caracteres, letras y números',
            controller: _nueva,
            obscure: true,
          ),
          _CampoModal(
            label: 'Confirmar nueva contraseña',
            hint: 'Repite la nueva contraseña',
            controller: _confirmar,
            obscure: true,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: ImageOption(
                  icono: Icons.arrow_back,
                  texto: 'Volver',
                  centrado: true,
                  onTap: () => setState(() => _cambiandoPassword = false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ImageOption(
                  icono: Icons.check,
                  texto: _guardando ? 'Guardando…' : 'Guardar',
                  centrado: true,
                  onTap: _guardando ? null : _guardarPassword,
                ),
              ),
            ],
          ),
        ],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ImageOption(
          icono: Icons.key,
          texto: 'Cambiar Contraseña',
          onTap: () => setState(() => _cambiandoPassword = true),
        ),
        const SizedBox(height: 14),
        ImageOption(
          icono: Icons.mail_outline,
          texto: 'Correo institucional',
          onTap: () => mostrarNotificacion(
            context,
            'Tu correo @unicesar.edu.co está verificado y no se puede cambiar desde la app.',
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════
// Lista de seguidores / siguiendo
// ═════════════════════════════════════════════════════════════
/// Modal genérico para seguidores o siguiendo: cubre carga, error, lista
/// vacía y abre el perfil de la persona tocada.
Future<void> mostrarListaPersonas(
  BuildContext context, {
  required String titulo,
  required IconData icono,
  required Future<List<PersonaResumen>> personas,
  required String vacio,
  required void Function(PersonaResumen) onTapPersona,
}) {
  return mostrarImageMenu<void>(
    context,
    titulo: titulo,
    icono: icono,
    builder: (ctx) => FutureBuilder<List<PersonaResumen>>(
      future: personas,
      builder: (ctx, snap) {
        Widget aviso(String texto) => Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            texto,
            textAlign: TextAlign.center,
            style: AppText.poppins(14, color: AppColors.texto2),
          ),
        );
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: AppColors.teal),
            ),
          );
        }
        if (snap.hasError) {
          final e = snap.error;
          return aviso(e is ApiException ? e.mensaje : 'No se pudo cargar la lista');
        }
        final lista = snap.data!;
        if (lista.isEmpty) return aviso(vacio);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final p in lista)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: MenuItem(
                  icono: Icons.person,
                  title: p.nombre,
                  desc: p.universidad.isEmpty ? 'Sin universidad' : p.universidad,
                  leading: ClipOval(child: fotoPerfil(p.avatarUrl, size: 44)),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    onTapPersona(p);
                  },
                ),
              ),
          ],
        );
      },
    ),
  );
}

// ═════════════════════════════════════════════════════════════
// Reportar (POST /api/reportes): a un usuario o un problema general
// ═════════════════════════════════════════════════════════════
// Códigos que espera la API, con su etiqueta visible en los chips.
const Map<String, String> _motivosUsuario = {
  'usuario_acoso': 'Acoso',
  'usuario_fraude': 'Fraude o estafa',
  'usuario_suplantacion': 'Suplantación de identidad',
  'usuario_spam': 'Spam',
  'usuario_abuso': 'Lenguaje abusivo',
  'usuario_comportamiento': 'Otro comportamiento',
};
const Map<String, String> _motivosGenerales = {
  'bug_tecnico': 'Error de la app',
  'queja_general': 'Queja',
  'sugerencia': 'Sugerencia',
  'otro': 'Otro',
};

/// Reporte general o contra un usuario según [idUsuario]; la API valida el
/// resto, aquí sólo se comprueban longitudes mínimas.
Future<void> mostrarReportar(
  BuildContext context, {
  int? idUsuario,
  String? nombreUsuario,
}) {
  return mostrarImageMenu<void>(
    context,
    titulo: idUsuario == null ? 'Reportar un problema' : 'Reportar a ${nombreUsuario ?? 'usuario'}',
    icono: Icons.flag_outlined,
    builder: (ctx) => _ReporteContenido(idUsuario: idUsuario),
  );
}

/// Formulario de reporte: motivo, título y descripción.
class _ReporteContenido extends StatefulWidget {
  final int? idUsuario;
  const _ReporteContenido({this.idUsuario});

  @override
  State<_ReporteContenido> createState() => _ReporteContenidoState();
}

class _ReporteContenidoState extends State<_ReporteContenido> {
  late final Map<String, String> _motivos =
      widget.idUsuario == null ? _motivosGenerales : _motivosUsuario;
  late String _tipo = _motivos.keys.first;
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  bool _enviando = false;

  @override
  void dispose() {
    _titulo.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final titulo = _titulo.text.trim();
    final descripcion = _descripcion.text.trim();
    if (titulo.length < 5) {
      mostrarNotificacion(context, 'El título debe tener al menos 5 caracteres');
      return;
    }
    if (descripcion.length < 10) {
      mostrarNotificacion(context, 'Describe lo ocurrido (mínimo 10 caracteres)');
      return;
    }
    setState(() => _enviando = true);
    try {
      await PerfilRepository.instance.reportar(
        tipo: _tipo,
        titulo: titulo,
        descripcion: descripcion,
        idUsuarioReportado: widget.idUsuario,
      );
      if (!mounted) return;
      await mostrarNotificacion(context, 'Reporte enviado. El equipo lo revisará.', exito: true);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Motivo', style: AppText.poppins(13.6, color: AppColors.texto2)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in _motivos.entries)
              ChoiceChip(
                label: Text(m.value),
                selected: _tipo == m.key,
                onSelected: (_) => setState(() => _tipo = m.key),
                selectedColor: AppColors.a(AppColors.teal, 0.25),
                backgroundColor: const Color(0x0DFFFFFF),
                labelStyle: AppText.poppins(12.8),
                side: BorderSide(
                  color: _tipo == m.key ? AppColors.teal : const Color(0x26FFFFFF),
                ),
                showCheckmark: false,
              ),
          ],
        ),
        const SizedBox(height: 14),
        _CampoModal(
          label: 'Título',
          hint: 'Resumen en pocas palabras',
          controller: _titulo,
          maxLength: 150,
        ),
        _CampoModal(
          label: 'Descripción',
          hint: '¿Qué pasó? Incluye fechas o detalles útiles',
          controller: _descripcion,
          lineas: 5,
          maxLength: 2000,
        ),
        ImageOption(
          icono: Icons.send,
          texto: _enviando ? 'Enviando…' : 'Enviar reporte',
          centrado: true,
          onTap: _enviando ? null : _enviar,
        ),
      ],
    );
  }
}
