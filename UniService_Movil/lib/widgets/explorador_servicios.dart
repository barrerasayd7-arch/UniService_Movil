// Archivo: explorador_servicios.dart
// Responsabilidad: buscador, filtros por categoría, destacados y resultados paginados de servicios.
// Se usa desde: inicio con sesión y inicio de invitado.

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/categorias.dart';
import '../data/api_client.dart';
import '../data/servicios_repository.dart';
import '../models/servicio.dart';
import 'tarjeta_servicio.dart';

/// Buscador + categorías + "Mejor calificados" + resultados de `GET /api/servicios`.
/// Lo usan el inicio (con sesión) y el inicio de invitado.
///
/// - Busca mientras se escribe (espera a que se deje de teclear); categoría y orden
///   se aplican en el servidor.
/// - Sin búsqueda ni filtro, muestra primero los mejor calificados en una fila deslizable.
/// - Los resultados crecen con "Ver más" (pide la página siguiente).
/// - Se recarga solo cuando el usuario publica, edita o borra un servicio.
class ExploradorServicios extends StatefulWidget {
  final void Function(Servicio) onTapServicio;

  /// Va encima del buscador (saludo o título de la sección).
  final Widget encabezado;

  /// Para pruebas; por defecto el repositorio de la app.
  final ServiciosRepository? repositorio;

  const ExploradorServicios({
    super.key,
    required this.onTapServicio,
    required this.encabezado,
    this.repositorio,
  });

  @override
  State<ExploradorServicios> createState() => ExploradorServiciosState();
}

// Etiqueta corta del orden actual para el botón (las largas viven en la hoja de opciones).
const _etiquetaOrden = {
  'recientes': 'Recientes',
  'antiguos': 'Antiguos',
  'precio-menor': 'Menor precio',
  'precio-mayor': 'Mayor precio',
  'rating-mayor': 'Mejor calificados',
  'rating-menor': 'Peor calificados',
};

const _porPagina = 12;

class ExploradorServiciosState extends State<ExploradorServicios> {
  // --- Estado de búsqueda, filtros y paginación ---

  late final ServiciosRepository _repo =
      widget.repositorio ?? ServiciosRepository.instance;
  final _busqueda = TextEditingController();
  Timer? _espera;
  String _chip = 'todos';
  String _orden = 'recientes';

  List<Servicio> _servicios = const [];
  List<Servicio> _destacados = const [];
  int _pagina = 0;
  int _total = 0;
  bool _hayMas = false;
  bool _cargando = true;
  bool _cargandoMas = false;
  String? _error;
  String? _errorMas;

  // Cada búsqueda nueva invalida las respuestas que lleguen tarde de las anteriores.
  int _peticion = 0;

  bool get _filtrando => _busqueda.text.trim().isNotEmpty || _chip != 'todos';

  int? get _idCategoria =>
      chipsCategoria.firstWhere((c) => c.valor == _chip).idCategoria;

  @override
  void initState() {
    super.initState();
    _repo.cambios.addListener(recargar);
    recargar();
  }

  @override
  void dispose() {
    _repo.cambios.removeListener(recargar);
    _espera?.cancel();
    _busqueda.dispose();
    super.dispose();
  }

  // --- Carga de datos ---

  /// Vuelve a pedir resultados y destacados (deslizar hacia abajo, o tras un cambio).
  Future<void> recargar() => Future.wait([_cargar(), _cargarDestacados()]);

  Future<void> _cargar({bool mas = false}) async {
    final id = mas ? _peticion : ++_peticion;
    setState(() {
      if (mas) {
        _cargandoMas = true;
        _errorMas = null;
      } else {
        _cargando = true;
        _error = null;
      }
    });
    try {
      final p = await _repo.listar(
        pagina: mas ? _pagina + 1 : 1,
        porPagina: _porPagina,
        categoria: _idCategoria,
        busqueda: _busqueda.text,
        orden: _orden,
      );
      if (!mounted || id != _peticion) return;
      setState(() {
        _servicios = mas ? [..._servicios, ...p.servicios] : p.servicios;
        _pagina = p.pagina;
        _total = p.total;
        _hayMas = p.hayMas;
      });
    } on ApiException catch (e) {
      if (!mounted || id != _peticion) return;
      setState(() => mas ? _errorMas = e.mensaje : _error = e.mensaje);
    } finally {
      if (mounted && id == _peticion) {
        setState(() => mas ? _cargandoMas = false : _cargando = false);
      }
    }
  }

  // Los 5 mejor calificados que tengan al menos una reseña.
  Future<void> _cargarDestacados() async {
    try {
      final p = await _repo.listar(porPagina: 10, orden: 'rating-mayor');
      if (!mounted) return;
      setState(
        () => _destacados = p.servicios
            .where((s) => s.numResenas > 0)
            .take(5)
            .toList(),
      );
    } on ApiException {
      // La fila es opcional: si falla, simplemente no se muestra.
    }
  }

  // --- Acciones de búsqueda y filtros ---

  void _alEscribir(String _) {
    setState(() {}); // muestra u oculta los destacados
    _espera?.cancel();
    _espera = Timer(const Duration(milliseconds: 350), _cargar);
  }

  void _elegirChip(String valor) {
    if (valor == _chip) return;
    _espera?.cancel();
    setState(() => _chip = valor);
    _cargar();
  }

  void _limpiarFiltros() {
    _espera?.cancel();
    _busqueda.clear();
    setState(() => _chip = 'todos');
    _cargar();
  }

  Future<void> _elegirOrden() async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Ordenar por', style: AppText.serif(22)),
            ),
            for (final e in opcionesOrden.entries)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(
                  e.value,
                  style: AppText.poppins(
                    15,
                    weight: e.key == _orden ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
                trailing: e.key == _orden
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.of(ctx).pop(e.key),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (elegido != null && elegido != _orden) {
      setState(() => _orden = elegido);
      _cargar();
    }
  }

  // --- Construcción de la vista ---

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < Breakpoints.mobile;
    final margen = movil ? 16.0 : 24.0;
    final destacados = _filtrando ? const <Servicio>[] : _destacados;
    final primeraCarga = _cargando && _servicios.isEmpty;

    final Widget resultados;
    if (primeraCarga) {
      resultados = const _RejillaEsqueleto();
    } else if (_error != null && _servicios.isEmpty) {
      resultados = _Aviso(
        icono: Icons.cloud_off_rounded,
        titulo: 'No pudimos cargar los servicios',
        texto: _error!,
        boton: 'Reintentar',
        onBoton: _cargar,
      );
    } else if (_servicios.isEmpty) {
      final q = _busqueda.text.trim();
      resultados = _Aviso(
        icono: _filtrando ? Icons.search_off_rounded : Icons.storefront_outlined,
        titulo: q.isNotEmpty
            ? 'Sin resultados para "$q"'
            : _filtrando
            ? 'No hay servicios en esta categoría'
            : 'Todavía no hay servicios publicados',
        texto: _filtrando
            ? 'Prueba con otra palabra o elige otra categoría.'
            : 'Sé el primero en ofrecer lo que sabes hacer.',
        boton: _filtrando ? 'Ver todos' : null,
        onBoton: _limpiarFiltros,
      );
    } else {
      resultados = RejillaServicios(
        servicios: _servicios,
        onTapServicio: widget.onTapServicio,
      );
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1200),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(margen, 24, margen, 0),
              child: widget.encabezado,
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(margen, 16, margen, 0),
              child: _Buscador(controller: _busqueda, onChanged: _alEscribir),
            ),
            const SizedBox(height: 12),
            _FiltroCategorias(
              seleccionado: _chip,
              margen: margen,
              onChanged: _elegirChip,
            ),
            if (destacados.isNotEmpty) ...[
              _TituloSeccion(texto: 'Mejor calificados', margen: margen),
              _FilaDestacados(
                servicios: destacados,
                margen: margen,
                onTap: widget.onTapServicio,
              ),
            ],
            _TituloSeccion(
              texto: _filtrando && !primeraCarga
                  ? (_total == 1 ? '1 resultado' : '$_total resultados')
                  : 'Todos los servicios',
              margen: margen,
              accion: _total > 1
                  ? TextButton.icon(
                      onPressed: _elegirOrden,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.teal,
                        minimumSize: const Size(48, 44),
                      ),
                      icon: const Icon(Icons.swap_vert_rounded, size: 18),
                      label: Text(
                        _etiquetaOrden[_orden]!,
                        style: AppText.poppins(
                          13.5,
                          weight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    )
                  : null,
            ),
            // Recargando con resultados en pantalla: barra fina en vez de vaciar la lista.
            if (_cargando && _servicios.isNotEmpty)
              Padding(
                padding: EdgeInsets.fromLTRB(margen, 0, margen, 8),
                child: const LinearProgressIndicator(
                  minHeight: 2,
                  color: AppColors.teal,
                  backgroundColor: AppColors.borde,
                ),
              ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margen),
              child: resultados,
            ),
            if (_servicios.isNotEmpty && (_hayMas || _errorMas != null))
              Padding(
                padding: EdgeInsets.fromLTRB(margen, 20, margen, 0),
                child: _BotonVerMas(
                  cargando: _cargandoMas,
                  error: _errorMas,
                  restantes: _total - _servicios.length,
                  onTap: () => _cargar(mas: true),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// Campo de búsqueda con botón para borrar; avisa cada cambio al explorador.
class _Buscador extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  const _Buscador({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => FocusScope.of(context).unfocus(),
        onTapOutside: (_) => FocusScope.of(context).unfocus(),
        cursorColor: AppColors.teal,
        style: AppText.poppins(15),
        decoration: InputDecoration(
          filled: true,
          fillColor: AppColors.card,
          hintText: 'Busca tutorías, diseño, arriendo…',
          hintStyle: AppText.poppins(15, color: AppColors.placeholder),
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: AppColors.teal,
            size: 22,
          ),
          suffixIcon: controller.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Borrar búsqueda',
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.texto2,
                    size: 20,
                  ),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.bordeCampo),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.teal, width: 1.6),
          ),
        ),
      ),
    );
  }
}

/// Fila deslizable de categorías (una sola fila, empieza en "Todos").
class _FiltroCategorias extends StatelessWidget {
  final String seleccionado;
  final double margen;
  final ValueChanged<String> onChanged;
  const _FiltroCategorias({
    required this.seleccionado,
    required this.margen,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margen),
        itemCount: chipsCategoria.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = chipsCategoria[i];
          final activo = c.valor == seleccionado;
          return Center(
            key: ValueKey('chip-${c.valor}'),
            child: Semantics(
              selected: activo,
              button: true,
              child: Material(
                color: activo ? AppColors.teal : AppColors.card,
                shape: StadiumBorder(
                  side: BorderSide(
                    color: activo ? AppColors.teal : AppColors.borde2,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => onChanged(c.valor),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          c.icono,
                          size: 16,
                          color: activo ? AppColors.bg : AppColors.texto2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          c.label,
                          style: AppText.poppins(
                            13.5,
                            weight: FontWeight.w600,
                            color: activo ? AppColors.bg : AppColors.texto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// Título de bloque con una acción opcional a la derecha (por ejemplo, ordenar).
class _TituloSeccion extends StatelessWidget {
  final String texto;
  final double margen;
  final Widget? accion;
  const _TituloSeccion({
    required this.texto,
    required this.margen,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        margen,
        24,
        margen - (accion == null ? 0 : 8),
        12,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.serif(21),
            ),
          ),
          ?accion,
        ],
      ),
    );
  }
}

/// Carrusel horizontal: deja ver el borde de la siguiente tarjeta para indicar que se desliza.
class _FilaDestacados extends StatelessWidget {
  final List<Servicio> servicios;
  final double margen;
  final void Function(Servicio) onTap;
  const _FilaDestacados({
    required this.servicios,
    required this.margen,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pantalla = MediaQuery.sizeOf(context).width;
    final ancho = (pantalla * 0.78).clamp(260.0, 320.0);
    final alto = TarjetaServicio.altoPara(
      ancho,
      MediaQuery.textScalerOf(context),
    );
    return SizedBox(
      height: alto,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: margen),
        itemCount: servicios.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, i) => SizedBox(
          width: ancho,
          child: TarjetaServicio(
            servicio: servicios[i],
            onTap: () => onTap(servicios[i]),
            alturaUniforme: true,
          ),
        ),
      ),
    );
  }
}

// Botón de paginación; también muestra el error de la página siguiente.
class _BotonVerMas extends StatelessWidget {
  final bool cargando;
  final String? error;
  final int restantes;
  final VoidCallback onTap;
  const _BotonVerMas({
    required this.cargando,
    required this.error,
    required this.restantes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text(
              error!,
              textAlign: TextAlign.center,
              style: AppText.poppins(13, color: AppColors.errorTexto),
            ),
          ),
        OutlinedButton(
          onPressed: cargando ? null : onTap,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.teal,
            side: const BorderSide(color: AppColors.bordeCampo),
            minimumSize: const Size(220, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: cargando
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.teal,
                  ),
                )
              : Text(
                  error != null
                      ? 'Reintentar'
                      : 'Ver más servicios ($restantes)',
                  style: AppText.poppins(
                    14,
                    weight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
        ),
      ],
    );
  }
}

/// Aviso en lugar de resultados: sin resultados, sin servicios o error de red.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String? boton;
  final VoidCallback onBoton;
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onBoton,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 32),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        children: [
          Icon(icono, size: 36, color: AppColors.texto2),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: AppText.poppins(15.5, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            texto,
            textAlign: TextAlign.center,
            style: AppText.poppins(13.5, color: AppColors.texto2, height: 1.45),
          ),
          if (boton != null) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onBoton,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.teal,
                side: const BorderSide(color: AppColors.bordeCampo),
                minimumSize: const Size(160, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                boton!,
                style: AppText.poppins(
                  14,
                  weight: FontWeight.w600,
                  color: AppColors.teal,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tarjetas grises con la forma de las reales mientras llega la primera página.
class _RejillaEsqueleto extends StatelessWidget {
  const _RejillaEsqueleto();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Cargando servicios',
      child: LayoutBuilder(
        builder: (context, box) {
          const gap = 16.0;
          final cols = ((box.maxWidth + gap) / (300 + gap)).floor().clamp(1, 4);
          final ancho = (box.maxWidth - gap * (cols - 1)) / cols;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < (cols == 1 ? 2 : cols * 2); i++)
                SizedBox(width: ancho, child: const _TarjetaEsqueleto()),
            ],
          );
        },
      ),
    );
  }
}

// Placeholder de una tarjeta mientras se cargan los datos reales.
class _TarjetaEsqueleto extends StatelessWidget {
  const _TarjetaEsqueleto();

  @override
  Widget build(BuildContext context) {
    Widget barra(double factor, double alto) => FractionallySizedBox(
      widthFactor: factor,
      alignment: Alignment.centerLeft,
      child: Container(
        height: alto,
        decoration: BoxDecoration(
          color: AppColors.bg3,
          borderRadius: BorderRadius.circular(6),
        ),
      ),
    );
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AspectRatio(
            aspectRatio: 16 / 9,
            child: ColoredBox(color: AppColors.bg3),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                barra(0.8, 16),
                const SizedBox(height: 10),
                barra(1, 12),
                const SizedBox(height: 6),
                barra(0.6, 12),
                const SizedBox(height: 14),
                barra(0.4, 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
