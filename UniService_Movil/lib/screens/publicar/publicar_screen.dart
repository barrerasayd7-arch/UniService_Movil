// Archivo: publicar_screen.dart
// Responsabilidad: formulario de alta y edición de un servicio (datos, fotos y contacto).
// Se usa desde: ruta '/publicar' (Mis servicios y el detalle de un servicio propio).

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/servicios_repository.dart';
import '../../models/servicio_detalle.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;

const _maxFotos = 5;
const _maxBytesFoto = 5 * 1024 * 1024;

/// Foto del formulario: ya subida ([id] y [url]) o recién elegida ([bytes]).
/// Las nuevas se suben al guardar; las subidas se comparan con `_idsOriginales`.
class _Foto {
  final int? id;
  final String? url;
  final Uint8List? bytes;
  final String nombre;
  const _Foto.subida(int this.id, String this.url) : bytes = null, nombre = '';
  const _Foto.nueva(Uint8List this.bytes, this.nombre) : id = null, url = null;

  bool get esNueva => bytes != null;
}

/// Publicar un servicio (`POST /api/servicios`) o editar uno propio ([idServicio]).
/// Al guardar, el servicio queda en revisión hasta que un administrador lo apruebe.
class PublicarScreen extends StatefulWidget {
  final int? idServicio;
  final ServiciosRepository? repositorio;
  const PublicarScreen({super.key, this.idServicio, this.repositorio});

  @override
  State<PublicarScreen> createState() => _PublicarScreenState();
}

/// Estado del formulario: controla los campos, la galería local y el guardado
/// en dos fases (datos del servicio y luego sus imágenes).
class _PublicarScreenState extends State<PublicarScreen> {
  late final ServiciosRepository _repo =
      widget.repositorio ?? ServiciosRepository.instance;

  // --- Campos y estado del formulario ---
  final _form = GlobalKey<FormState>();
  final _titulo = TextEditingController();
  final _descripcion = TextEditingController();
  final _precio = TextEditingController();
  final _contacto = TextEditingController();
  final _direccion = TextEditingController();

  late int? _id = widget.idServicio; // null = alta; con id = edición
  int? _categoria;
  String _unidad = 'hora';
  bool _unidadElegida = false; // si el usuario la tocó, no se cambia sola
  String _modalidad = 'presencial';
  String _disponibilidad = 'siempre';
  List<_Foto> _fotos = [];
  List<int> _idsOriginales = []; // fotos subidas al abrir, en su orden

  bool _cargando = false;
  String? _errorCarga;
  bool _guardando = false;
  String _paso = ''; // texto de progreso mostrado en la barra inferior
  bool _cambios = false; // activa el aviso al intentar salir
  bool _intentoEnviar = false; // desde el primer envío se valida al escribir

  bool get _editando => _id != null;
  bool get _esArriendo => _categoria == idCategoriaArriendo;

  @override
  void initState() {
    super.initState();
    for (final c in [_titulo, _descripcion, _precio, _contacto, _direccion]) {
      c.addListener(_marcarCambio);
    }
    if (_editando) _cargar();
  }

  @override
  void dispose() {
    for (final c in [_titulo, _descripcion, _precio, _contacto, _direccion]) {
      c.dispose();
    }
    super.dispose();
  }

  void _marcarCambio() => _cambios = true;

  /// Trae el servicio a editar (`GET /api/servicios/{id}`) y rellena el formulario.
  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _errorCarga = null;
    });
    try {
      final d = await _repo.detalle(_id!);
      if (!mounted) return;
      _rellenar(d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorCarga = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Copia los datos remotos al estado local; la galería parte de las imágenes
  /// ya subidas y se recuerda su orden para detectar cambios.
  void _rellenar(ServicioDetalle d) {
    final s = d.servicio;
    _titulo.text = s.titulo;
    _descripcion.text = s.descripcion;
    _precio.text = '${s.precio}';
    _contacto.text = d.contacto ?? '';
    _direccion.text = d.direccion ?? '';
    setState(() {
      _categoria = s.idCategoria;
      _unidad = s.unidadPrecio;
      _unidadElegida = true;
      _modalidad = s.modalidad;
      _disponibilidad = s.disponibilidad;
      _fotos = [
        for (final i in d.imagenes)
          if (i.url != null) _Foto.subida(i.id, i.url!),
      ];
      _idsOriginales = [for (final f in _fotos) f.id!];
      _cambios = false;
    });
  }

  /// El arriendo sugiere precio por mes; el resto, por hora, salvo que el
  /// usuario ya haya elegido la unidad manualmente.
  void _elegirCategoria(int id) {
    setState(() {
      _categoria = id;
      if (!_unidadElegida) _unidad = id == idCategoriaArriendo ? 'mes' : 'hora';
      _cambios = true;
    });
  }

  // --- Fotos ---

  /// Abre galería o cámara, descarta lo que pase de 5 MB y respeta el máximo
  /// de fotos. Las imágenes se comprimen en el dispositivo antes de subirlas.
  Future<void> _agregarFotos() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar una foto'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (origen == null) return;

    final picker = ImagePicker();
    final restantes = _maxFotos - _fotos.length;
    List<XFile> elegidas;
    try {
      // Reducidas en el teléfono: suben más rápido y quedan bajo el límite de 5 MB.
      elegidas = origen == ImageSource.camera
          ? [
              ?await picker.pickImage(
                source: ImageSource.camera,
                maxWidth: 1920,
                maxHeight: 1920,
                imageQuality: 85,
              ),
            ]
          : await picker.pickMultiImage(
              maxWidth: 1920,
              maxHeight: 1920,
              imageQuality: 85,
              limit: restantes > 1 ? restantes : null,
            );
    } on PlatformException {
      if (mounted) {
        mostrarNotificacion(
          context,
          'No pudimos abrir tus fotos. Revisa los permisos de la app.',
        );
      }
      return;
    }
    if (elegidas.isEmpty) return;

    final nuevas = <_Foto>[];
    var pesadas = 0;
    for (final x in elegidas.take(restantes)) {
      final bytes = await x.readAsBytes();
      if (bytes.length > _maxBytesFoto) {
        pesadas++;
        continue;
      }
      nuevas.add(_Foto.nueva(bytes, x.name));
    }
    if (!mounted) return;
    setState(() {
      _fotos = [..._fotos, ...nuevas];
      _cambios = true;
    });
    if (elegidas.length > restantes) {
      mostrarNotificacion(
        context,
        'Un servicio admite $_maxFotos fotos; agregamos las primeras $restantes.',
      );
    } else if (pesadas > 0) {
      mostrarNotificacion(
        context,
        pesadas == 1
            ? 'Una foto pesa más de 5 MB y no se agregó.'
            : '$pesadas fotos pesan más de 5 MB y no se agregaron.',
      );
    }
  }

  /// Acciones de una foto: moverla a portada (posición 0) o quitarla de la lista.
  Future<void> _opcionesFoto(int i) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (i > 0)
              ListTile(
                leading: const Icon(Icons.star_outline_rounded),
                title: const Text('Usar como portada'),
                onTap: () => Navigator.of(ctx).pop('portada'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.errorTexto,
              ),
              title: const Text(
                'Quitar foto',
                style: TextStyle(color: AppColors.errorTexto),
              ),
              onTap: () => Navigator.of(ctx).pop('quitar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (accion == null) return;
    setState(() {
      final f = _fotos.removeAt(i);
      if (accion == 'portada') _fotos.insert(0, f);
      _cambios = true;
    });
  }

  // --- Guardar ---

  /// Validación fuera del `Form`: la categoría no es un `TextFormField`.
  String? _validarFormulario() {
    if (_categoria == null) return 'Elige una categoría';
    return null;
  }

  /// Crea o edita el servicio y luego sincroniza sus fotos. Si la creación tuvo
  /// éxito pero fallaron las imágenes, se queda en edición para reintentar.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _intentoEnviar = true);
    final valido = _form.currentState!.validate();
    final errorExtra = _validarFormulario();
    if (!valido || errorExtra != null) {
      if (errorExtra != null) mostrarNotificacion(context, errorExtra);
      return;
    }

    final datos = DatosServicio(
      titulo: _titulo.text,
      descripcion: _descripcion.text,
      idCategoria: _categoria!,
      precio: int.parse(_precio.text),
      unidadPrecio: _unidad,
      modalidad: _modalidad,
      disponibilidad: _disponibilidad,
      contacto: _contacto.text,
      direccion: _esArriendo ? _direccion.text : null,
    );

    setState(() => _guardando = true);
    final nuevo = !_editando;
    try {
      _setPaso(nuevo ? 'Publicando…' : 'Guardando cambios…');
      if (nuevo) {
        _id = await _repo.crear(datos);
      } else {
        await _repo.editar(_id!, datos);
      }
      await _sincronizarFotos();
      if (!mounted) return;
      _cambios = false;
      await mostrarNotificacion(
        context,
        nuevo
            ? 'Tu servicio quedó en revisión. Te avisaremos por correo cuando un administrador lo apruebe.'
            : 'Cambios guardados. Tu servicio vuelve a revisión antes de mostrarse de nuevo.',
        exito: true,
      );
      if (!mounted) return;
      if (nuevo) {
        Navigator.of(context).pushReplacementNamed('/mis-servicios');
      } else {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      // Si el servicio ya se creó pero fallaron las fotos, el formulario pasa a
      // modo edición para reintentar sin duplicar el servicio.
      if (nuevo && _id != null) {
        setState(() {});
        mostrarNotificacion(
          context,
          'El servicio se guardó, pero las fotos no se pudieron subir: ${e.mensaje} Toca "Guardar" para reintentar.',
        );
      } else {
        mostrarNotificacion(context, e.mensaje);
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  void _setPaso(String paso) {
    if (mounted) setState(() => _paso = paso);
  }

  /// Borra las fotos quitadas, sube las nuevas y deja el orden elegido.
  Future<void> _sincronizarFotos() async {
    final id = _id!;
    final conservadas = {for (final f in _fotos) ?f.id};
    final borradas = _idsOriginales.where((i) => !conservadas.contains(i));
    if (borradas.isNotEmpty) _setPaso('Quitando fotos…');
    for (final i in borradas) {
      await _repo.eliminarImagen(id, i);
    }
    _idsOriginales = _idsOriginales.where(conservadas.contains).toList();

    final nuevas = _fotos.where((f) => f.esNueva).toList();
    if (nuevas.isNotEmpty) {
      _setPaso(
        nuevas.length == 1 ? 'Subiendo la foto…' : 'Subiendo ${nuevas.length} fotos…',
      );
      await _repo.subirImagenes(id, [
        for (final f in nuevas) (bytes: f.bytes!, nombre: f.nombre),
      ]);
    }

    // La API deja las subidas al final. Se cambian las fotos locales por las ya subidas
    // (así un reintento no las sube dos veces) y, si el orden elegido es otro, se reordena.
    final d = await _repo.detalle(id);
    final enServidor = [
      for (final i in d.imagenes)
        if (i.url != null) _Foto.subida(i.id, i.url!),
    ];
    final subidas = enServidor.skip(_idsOriginales.length).iterator;
    _fotos = [
      for (final f in _fotos)
        if (!f.esNueva) f else if (subidas.moveNext()) subidas.current,
    ];
    _idsOriginales = [for (final f in enServidor) f.id!];
    final deseado = [for (final f in _fotos) f.id!];
    if (deseado.length == _idsOriginales.length &&
        !listEquals(deseado, _idsOriginales)) {
      _setPaso('Ordenando fotos…');
      await _repo.ordenarImagenes(id, deseado);
      _idsOriginales = deseado;
    }
  }

  /// Atrás/cerrar pide confirmación sólo si hay cambios sin guardar; durante
  /// el guardado bloquea la salida.
  Future<bool> _confirmarSalida() async {
    if (!_cambios || _guardando) return !_guardando;
    final salir = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('¿Descartar los cambios?', style: AppText.serif(22)),
        content: Text(
          'Lo que escribiste no se guardará.',
          style: AppText.poppins(14, color: AppColors.texto2),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorTexto),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return salir == true;
  }

  // --- Interfaz ---

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmarSalida() && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text(
            _editando ? 'Editar servicio' : 'Publicar servicio',
            style: AppText.serif(22),
          ),
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.borde),
          ),
        ),
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              )
            : _errorCarga != null
            ? _ErrorCarga(mensaje: _errorCarga!, onReintentar: _cargar)
            : _formulario(),
        bottomNavigationBar: _cargando || _errorCarga != null
            ? null
            : _BarraGuardar(
                texto: _editando ? 'Guardar cambios' : 'Publicar servicio',
                guardando: _guardando,
                paso: _paso,
                onTap: _guardar,
              ),
      ),
    );
  }

  Widget _formulario() {
    return Form(
      key: _form,
      autovalidateMode: _intentoEnviar
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: [
              _AvisoRevision(editando: _editando),
              const _Etiqueta('Fotos', ayuda: 'Hasta 5. La primera es la portada.'),
              _GaleriaFotos(
                fotos: _fotos,
                onAgregar: _fotos.length < _maxFotos ? _agregarFotos : null,
                onTapFoto: _opcionesFoto,
              ),
              const SizedBox(height: 24),
              const _Etiqueta('Título'),
              TextFormField(
                controller: _titulo,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                style: AppText.poppins(15),
                decoration: _deco('Ej: Clases de Cálculo Diferencial'),
                validator: (v) => (v ?? '').trim().length < 5
                    ? 'Escribe al menos 5 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),
              const _Etiqueta('Categoría'),
              _Opciones<int>(
                valor: _categoria,
                opciones: [
                  for (final (id, nombre) in categoriasServicio)
                    (id, etiquetaCategoria(nombre), iconosPorCategoria[nombre]),
                ],
                onChanged: _elegirCategoria,
              ),
              if (_intentoEnviar && _categoria == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6, left: 12),
                  child: Text(
                    'Elige una categoría',
                    style: AppText.poppins(12, color: AppColors.errorTexto),
                  ),
                ),
              const SizedBox(height: 24),
              const _Etiqueta(
                'Descripción',
                ayuda: 'Qué incluye, cómo trabajas y qué necesitas del cliente.',
              ),
              TextFormField(
                controller: _descripcion,
                minLines: 4,
                maxLines: 10,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                style: AppText.poppins(15, height: 1.5),
                decoration: _deco('Describe tu servicio…'),
                validator: (v) => (v ?? '').trim().length < 20
                    ? 'Escribe al menos 20 caracteres'
                    : null,
              ),
              const SizedBox(height: 12),
              const _Etiqueta('Precio (COP)'),
              TextFormField(
                controller: _precio,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(8),
                ],
                style: AppText.poppins(15),
                decoration: _deco('Ej: 25000').copyWith(
                  prefixText: '\$ ',
                  prefixStyle: AppText.poppins(15, color: AppColors.texto2),
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '') ?? 0;
                  if (n < 1000) return 'El precio mínimo es \$1.000';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              _Opciones<String>(
                valor: _unidad,
                opciones: [
                  for (final e in unidadesPrecio.entries)
                    (e.key, e.value, null),
                ],
                onChanged: (v) => setState(() {
                  _unidad = v;
                  _unidadElegida = true;
                  _cambios = true;
                }),
              ),
              const SizedBox(height: 24),
              const _Etiqueta('Modalidad'),
              _Opciones<String>(
                valor: _modalidad,
                opciones: [
                  (
                    'presencial',
                    'Presencial',
                    Icons.person_pin_circle_outlined,
                  ),
                  ('virtual', 'Virtual', Icons.videocam_outlined),
                  ('mixta', 'Mixta', Icons.sync_alt),
                ],
                onChanged: (v) => setState(() {
                  _modalidad = v;
                  _cambios = true;
                }),
              ),
              const SizedBox(height: 24),
              const _Etiqueta('Disponibilidad'),
              _Opciones<String>(
                valor: _disponibilidad,
                opciones: [
                  for (final e in disponibilidades.entries)
                    (e.key, e.value, null),
                ],
                onChanged: (v) => setState(() {
                  _disponibilidad = v;
                  _cambios = true;
                }),
              ),
              const SizedBox(height: 24),
              const _Etiqueta(
                'Contacto',
                ayuda:
                    'Un celular (abre WhatsApp) o un correo. Sólo lo ven usuarios con sesión.',
              ),
              TextFormField(
                controller: _contacto,
                keyboardType: TextInputType.emailAddress,
                maxLength: 150,
                buildCounter: _sinContador,
                style: AppText.poppins(15),
                decoration: _deco('Ej: 300 123 4567'),
                validator: (v) {
                  final t = (v ?? '').trim();
                  if (t.length < 5) return 'Indica un celular o correo';
                  if (t.contains('@')) {
                    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(t)
                        ? null
                        : 'Revisa el correo';
                  }
                  final digitos = t.replaceAll(RegExp(r'\D'), '');
                  return digitos.length < 7 ? 'Revisa el número' : null;
                },
              ),
              if (_esArriendo) ...[
                const SizedBox(height: 12),
                const _Etiqueta(
                  'Dirección (opcional)',
                  ayuda: 'Barrio o dirección aproximada. Sólo la ven usuarios con sesión.',
                ),
                TextFormField(
                  controller: _direccion,
                  maxLength: 300,
                  buildCounter: _sinContador,
                  textCapitalization: TextCapitalization.sentences,
                  style: AppText.poppins(15),
                  decoration: _deco('Ej: Calle 12 # 8-45, Valledupar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static Widget? _sinContador(
    BuildContext _, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  InputDecoration _deco(String hint) => InputDecoration(
    filled: true,
    fillColor: AppColors.card,
    hintText: hint,
    hintStyle: AppText.poppins(15, color: AppColors.placeholder),
    counterStyle: AppText.poppins(11.5, color: AppColors.texto3),
    errorStyle: AppText.poppins(12, color: AppColors.errorTexto),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordeCampo),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.errorTexto),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.errorTexto, width: 1.6),
    ),
  );
}

/// Recordatorio de que todo servicio pasa por revisión antes de publicarse.
class _AvisoRevision extends StatelessWidget {
  final bool editando;
  const _AvisoRevision({required this.editando});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.a(AppColors.teal, 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.a(AppColors.teal, 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.verified_outlined, color: AppColors.teal, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              editando
                  ? 'Al guardar, el servicio vuelve a revisión y deja de mostrarse hasta que un administrador lo apruebe.'
                  : 'Un administrador revisa cada servicio antes de publicarlo. Suele tardar menos de un día.',
              style: AppText.poppins(13, color: AppColors.texto2, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

/// Etiqueta de un campo con una ayuda opcional debajo.
class _Etiqueta extends StatelessWidget {
  final String texto;
  final String? ayuda;
  const _Etiqueta(this.texto, {this.ayuda});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(texto, style: AppText.poppins(14.5, weight: FontWeight.w600)),
          if (ayuda != null)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                ayuda!,
                style: AppText.poppins(12.5, color: AppColors.texto2),
              ),
            ),
        ],
      ),
    );
  }
}

/// Grupo de opciones de una sola elección, como chips que se acomodan en varias líneas.
class _Opciones<T> extends StatelessWidget {
  final T? valor;
  final List<(T, String, IconData?)> opciones;
  final ValueChanged<T> onChanged;
  const _Opciones({
    required this.valor,
    required this.opciones,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (v, texto, icono) in opciones)
          ChoiceChip(
            selected: v == valor,
            onSelected: (_) => onChanged(v),
            showCheckmark: false,
            avatar: icono == null
                ? null
                : Icon(
                    icono,
                    size: 17,
                    color: v == valor ? AppColors.bg : AppColors.texto2,
                  ),
            label: Text(texto),
            labelStyle: AppText.poppins(
              13.5,
              weight: FontWeight.w600,
              color: v == valor ? AppColors.bg : AppColors.texto2,
            ),
            materialTapTargetSize: MaterialTapTargetSize.padded,
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
            backgroundColor: AppColors.card,
            selectedColor: AppColors.teal,
            shape: StadiumBorder(
              side: BorderSide(
                color: v == valor ? AppColors.teal : AppColors.borde2,
              ),
            ),
          ),
      ],
    );
  }
}

/// Tira horizontal de fotos con la portada marcada y el botón para agregar.
class _GaleriaFotos extends StatelessWidget {
  final List<_Foto> fotos;
  final VoidCallback? onAgregar;
  final ValueChanged<int> onTapFoto;
  const _GaleriaFotos({
    required this.fotos,
    required this.onAgregar,
    required this.onTapFoto,
  });

  static const _lado = 104.0;

  @override
  Widget build(BuildContext context) {
    final cache = (_lado * MediaQuery.devicePixelRatioOf(context)).round();
    return SizedBox(
      height: _lado,
      child: ListView(
        scrollDirection: Axis.horizontal,
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < fotos.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Semantics(
                button: true,
                label: i == 0 ? 'Foto de portada. Opciones' : 'Foto ${i + 1}. Opciones',
                child: GestureDetector(
                  onTap: () => onTapFoto(i),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: _lado,
                      height: _lado,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          fotos[i].esNueva
                              ? Image.memory(
                                  fotos[i].bytes!,
                                  fit: BoxFit.cover,
                                  cacheWidth: cache,
                                )
                              : Image.network(
                                  fotos[i].url!,
                                  fit: BoxFit.cover,
                                  cacheWidth: cache,
                                  errorBuilder: (_, _, _) => const ColoredBox(
                                    color: AppColors.bg3,
                                    child: Icon(
                                      Icons.broken_image_outlined,
                                      color: AppColors.texto3,
                                    ),
                                  ),
                                ),
                          if (i == 0)
                            Positioned(
                              left: 6,
                              bottom: 6,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xE6070D16),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'Portada',
                                  style: AppText.poppins(
                                    11,
                                    weight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: CircleAvatar(
                              radius: 13,
                              backgroundColor: Color(0xCC070D16),
                              child: Icon(
                                Icons.more_horiz,
                                size: 16,
                                color: AppColors.texto,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (onAgregar != null)
            Semantics(
              button: true,
              label: 'Agregar fotos',
              child: InkWell(
                onTap: onAgregar,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: _lado,
                  height: _lado,
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.bordeCampo),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_photo_alternate_outlined,
                        color: AppColors.teal,
                        size: 28,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${fotos.length}/$_maxFotos',
                        style: AppText.poppins(12.5, color: AppColors.texto2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Barra inferior fija que guarda y muestra el paso actual del proceso.
class _BarraGuardar extends StatelessWidget {
  final String texto;
  final bool guardando;
  final String paso;
  final VoidCallback onTap;
  const _BarraGuardar({
    required this.texto,
    required this.guardando,
    required this.paso,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bg,
        border: Border(top: BorderSide(color: AppColors.borde)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 608),
              child: FilledButton(
                onPressed: guardando ? null : onTap,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: AppColors.bg,
                  disabledBackgroundColor: AppColors.a(AppColors.teal, 0.5),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: guardando
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.bg,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            paso,
                            style: AppText.poppins(
                              15,
                              weight: FontWeight.w700,
                              color: AppColors.bg,
                            ),
                          ),
                        ],
                      )
                    : Text(
                        texto,
                        style: AppText.poppins(
                          15.5,
                          weight: FontWeight.w700,
                          color: AppColors.bg,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Error al cargar el servicio a editar, con opción de reintentar.
class _ErrorCarga extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _ErrorCarga({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 44,
              color: AppColors.texto2,
            ),
            const SizedBox(height: 12),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppText.poppins(14.5, color: AppColors.texto2),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onReintentar,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
