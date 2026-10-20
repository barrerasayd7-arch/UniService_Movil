import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../data/admin_repository.dart';
import '../../data/api_client.dart';
import '../../models/admin_models.dart';
import '../login/auth_widgets.dart';
import 'admin_drawer.dart';

/// Si el servidor pide otra vez la contraseña de administrador, vuelve a la puerta
/// de acceso. true = ya redirigió (no hay nada más que mostrar).
bool volverAPedirClave(BuildContext context, ApiException e) {
  if (!e.requiereElevacion) return false;
  AdminRepository.instance.salir();
  Navigator.of(context).pushReplacementNamed('/admin');
  return true;
}

void avisoAdmin(BuildContext context, String texto) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(texto, style: AppText.poppins(14)),
        backgroundColor: AppColors.card,
        behavior: SnackBarBehavior.floating,
      ),
    );
}

/// Ejecuta una acción del panel: avisa si sale bien, muestra el error si falla.
/// Devuelve true si salió bien.
Future<bool> accionAdmin(
  BuildContext context,
  Future<void> Function() accion, {
  String? exito,
}) async {
  try {
    await accion();
    if (context.mounted && exito != null) avisoAdmin(context, exito);
    return true;
  } on ApiException catch (e) {
    if (!context.mounted) return false;
    if (!volverAPedirClave(context, e))
      await mostrarNotificacion(context, e.mensaje);
    return false;
  }
}

/// Imagen a pantalla completa con zoom.
void verImagenAdmin(BuildContext context, String url) {
  showDialog<void>(
    context: context,
    barrierColor: const Color(0xE6000000),
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(12),
      child: Stack(
        children: [
          InteractiveViewer(
            child: Center(
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.broken_image_outlined,
                  size: 48,
                  color: AppColors.texto3,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: 'Cerrar',
              onPressed: () => Navigator.of(ctx).pop(),
              icon: const Icon(Icons.close_rounded, color: AppColors.texto),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Pantalla del panel: barra con título, menú lateral y cuerpo.
class AdminScaffold extends StatelessWidget {
  final String actual;
  final String titulo;
  final Widget body;
  const AdminScaffold({
    super.key,
    required this.actual,
    required this.titulo,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      drawer: AdminDrawer(actual: actual),
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: AppColors.texto,
        title: Text(titulo, style: AppText.serif(22)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borde),
        ),
      ),
      body: SafeArea(top: false, child: body),
    );
  }
}

class MensajeAdmin extends StatelessWidget {
  final IconData icono;
  final String mensaje;
  final String? accion;
  final VoidCallback? onAccion;
  const MensajeAdmin({
    super.key,
    required this.icono,
    required this.mensaje,
    this.accion,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: 40, color: AppColors.texto2),
            const SizedBox(height: 14),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: AppText.poppins(15, color: AppColors.texto2, height: 1.5),
            ),
            if (accion != null) ...[
              const SizedBox(height: 18),
              SizedBox(
                width: 200,
                child: AuthPrimaryButton(
                  label: accion!,
                  color: AppColors.admin,
                  colorHover: AppColors.adminHover,
                  onTap: onAccion,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Buscador y/o chips de filtro, fijos sobre la lista.
class BarraFiltros extends StatelessWidget {
  final TextEditingController? buscador;
  final String hint;
  final ValueChanged<String>? onBuscar;
  final Widget? filtros;
  const BarraFiltros({
    super.key,
    this.buscador,
    this.hint = 'Buscar...',
    this.onBuscar,
    this.filtros,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (buscador != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: _Buscador(
                  controller: buscador!,
                  hint: hint,
                  onChanged: onBuscar ?? (_) {},
                ),
              ),
            if (filtros != null)
              Padding(
                padding: EdgeInsets.only(top: buscador == null ? 12 : 0),
                child: filtros!,
              ),
          ],
        ),
      ),
    );
  }
}

class _Buscador extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onChanged;
  const _Buscador({
    required this.controller,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    OutlineInputBorder borde(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (_, v, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        cursorColor: AppColors.admin,
        style: AppText.poppins(15),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: AppColors.bg2,
          hintText: hint,
          hintStyle: AppText.poppins(15, color: AppColors.placeholder),
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.placeholder,
          ),
          suffixIcon: v.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.placeholder,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          enabledBorder: borde(AppColors.bordeCampo),
          focusedBorder: borde(AppColors.admin, 1.6),
        ),
      ),
    );
  }
}

/// Opciones de una sola elección. En línea con scroll horizontal, o envueltas ([envolver]).
class FiltroChips<T> extends StatelessWidget {
  final T valor;
  final List<(T, String)> opciones;
  final ValueChanged<T> onChanged;
  final bool envolver;
  const FiltroChips({
    super.key,
    required this.valor,
    required this.opciones,
    required this.onChanged,
    this.envolver = false,
  });

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final (v, texto) in opciones)
        ChoiceChip(
          selected: v == valor,
          onSelected: (_) => onChanged(v),
          showCheckmark: false,
          label: Text(texto),
          labelStyle: AppText.poppins(
            13.5,
            weight: FontWeight.w600,
            color: v == valor ? AppColors.bg : AppColors.texto2,
          ),
          materialTapTargetSize: MaterialTapTargetSize.padded,
          backgroundColor: AppColors.card,
          selectedColor: AppColors.admin,
          shape: StadiumBorder(
            side: BorderSide(
              color: v == valor ? AppColors.admin : AppColors.borde2,
            ),
          ),
        ),
    ];
    if (envolver) return Wrap(spacing: 8, runSpacing: 8, children: chips);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          for (final c in chips)
            Padding(padding: const EdgeInsets.only(right: 8), child: c),
        ],
      ),
    );
  }
}

class TarjetaAdmin extends StatelessWidget {
  final Widget child;
  final Color? acento;
  final VoidCallback? onTap;
  const TarjetaAdmin({super.key, required this.child, this.acento, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.card,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borde),
        ),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: acento == null
                ? null
                : BoxDecoration(
                    border: Border(left: BorderSide(color: acento!, width: 3)),
                  ),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botón de acción pequeño (44 px de alto para el dedo).
class BotonAdmin extends StatelessWidget {
  final String label;
  final IconData? icono;
  final Color color;
  final VoidCallback? onTap;
  final bool relleno;
  final bool cargando;
  final bool expandido;
  const BotonAdmin({
    super.key,
    required this.label,
    required this.onTap,
    this.icono,
    this.color = AppColors.admin,
    this.relleno = false,
    this.cargando = false,
    this.expandido = false,
  });

  @override
  Widget build(BuildContext context) {
    final activo = onTap != null && !cargando;
    return Semantics(
      button: true,
      enabled: activo,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: onTap == null && !cargando ? 0.5 : 1,
        child: SizedBox(
          width: expandido ? double.infinity : null,
          child: Material(
            color: AppColors.a(color, relleno ? 0.18 : 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: AppColors.a(color, 0.4)),
            ),
            child: InkWell(
              onTap: activo ? onTap : null,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: expandido
                        ? MainAxisSize.max
                        : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (cargando)
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: color,
                          ),
                        )
                      else if (icono != null)
                        Icon(icono, size: 18, color: color),
                      if (cargando || icono != null) const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          label,
                          style: AppText.poppins(
                            13.5,
                            weight: FontWeight.w600,
                            color: color,
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
      ),
    );
  }
}

/// Etiqueta a la izquierda y valor a la derecha, para los detalles.
class FilaDatoAdmin extends StatelessWidget {
  final String label;
  final String value;
  const FilaDatoAdmin(this.label, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: AppText.poppins(13.5, color: AppColors.texto2),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppText.poppins(
                13.5,
                weight: FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Lista paginada del panel: carga la primera página, "cargar más" al llegar al final,
/// pull-to-refresh y estados de carga, error y vacío. Para recargar desde fuera usa
/// una `GlobalKey<ListaAdminState<T>>` y llama a `recargar()`.
class ListaAdmin<T> extends StatefulWidget {
  final Future<PaginaAdmin<T>> Function(int page) cargar;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final String vacio;
  final IconData iconoVacio;
  const ListaAdmin({
    super.key,
    required this.cargar,
    required this.itemBuilder,
    required this.vacio,
    required this.iconoVacio,
  });

  @override
  State<ListaAdmin<T>> createState() => ListaAdminState<T>();
}

class ListaAdminState<T> extends State<ListaAdmin<T>> {
  final _scroll = ScrollController();
  final List<T> _items = [];
  int _page = 0;
  bool _hayMas = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  bool _errorMas = false;
  String? _error;
  int _ticket = 0; // descarta respuestas de cargas anteriores

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_alScrollear);
    recargar();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _alScrollear() {
    if (_scroll.hasClients &&
        _scroll.position.extentAfter < 300 &&
        !_errorMas) {
      _cargarMas();
    }
  }

  /// [silencioso]: no vacía la lista mientras carga (tras una acción o al deslizar).
  Future<void> recargar({bool silencioso = false}) async {
    final t = ++_ticket;
    if (!silencioso) {
      setState(() {
        _items.clear();
        _cargando = true;
        _cargandoMas = false;
        _errorMas = false;
        _hayMas = false;
        _error = null;
      });
    }
    try {
      final p = await widget.cargar(1);
      if (!mounted || t != _ticket) return;
      setState(() {
        _items
          ..clear()
          ..addAll(p.items);
        _page = p.page;
        _hayMas = p.hayMas;
        _cargando = false;
        _cargandoMas = false;
        _errorMas = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted || t != _ticket) return;
      if (volverAPedirClave(context, e)) return;
      setState(() {
        _cargando = false;
        _error = _items.isEmpty ? e.mensaje : null;
      });
      if (_items.isNotEmpty) mostrarNotificacion(context, e.mensaje);
    }
  }

  Future<void> _cargarMas() async {
    if (!_hayMas || _cargandoMas || _cargando) return;
    final t = _ticket;
    setState(() => _cargandoMas = true);
    try {
      final p = await widget.cargar(_page + 1);
      if (!mounted || t != _ticket) return;
      setState(() {
        _items.addAll(p.items);
        _page = p.page;
        _hayMas = p.hayMas;
        _cargandoMas = false;
      });
    } on ApiException catch (e) {
      if (!mounted || t != _ticket) return;
      if (volverAPedirClave(context, e)) return;
      setState(() {
        _cargandoMas = false;
        _errorMas = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando && _items.isEmpty) {
      return const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.admin,
            semanticsLabel: 'Cargando',
          ),
        ),
      );
    }
    if (_error != null && _items.isEmpty) {
      return MensajeAdmin(
        icono: Icons.cloud_off_rounded,
        mensaje: _error!,
        accion: 'Reintentar',
        onAccion: () => recargar(),
      );
    }
    return RefreshIndicator(
      color: AppColors.admin,
      backgroundColor: AppColors.card,
      onRefresh: () => recargar(silencioso: true),
      child: _items.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: 320,
                  child: MensajeAdmin(
                    icono: widget.iconoVacio,
                    mensaje: widget.vacio,
                  ),
                ),
              ],
            )
          : ListView.builder(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              itemCount: _items.length + (_hayMas ? 1 : 0),
              itemBuilder: (ctx, i) {
                if (i >= _items.length) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: _errorMas
                          ? AuthTextButton(
                              label: 'No se pudo cargar más. Reintentar',
                              color: AppColors.admin,
                              onTap: () {
                                setState(() => _errorMas = false);
                                _cargarMas();
                              },
                            )
                          : const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: AppColors.admin,
                              ),
                            ),
                    ),
                  );
                }
                return Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: widget.itemBuilder(ctx, _items[i]),
                  ),
                );
              },
            ),
    );
  }
}
