import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_text.dart';
import '../core/categorias.dart';
import '../models/servicio.dart';
import 'tarjeta_servicio.dart';

/// Buscador + categorías + "Mejor calificados" + resultados.
/// Lo usan el inicio (con sesión) y el inicio de invitado.
///
/// - Busca mientras se escribe; las categorías acotan los resultados.
/// - Sin búsqueda ni filtro, muestra primero los mejor calificados en una fila deslizable.
/// - Los resultados crecen con "Ver más" (sin paginación numerada).
class ExploradorServicios extends StatefulWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;

  /// Va encima del buscador (saludo o título de la sección).
  final Widget encabezado;
  const ExploradorServicios({
    super.key,
    required this.servicios,
    required this.onTapServicio,
    required this.encabezado,
  });

  @override
  State<ExploradorServicios> createState() => _ExploradorServiciosState();
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

class _ExploradorServiciosState extends State<ExploradorServicios> {
  final _busqueda = TextEditingController();
  String _chip = 'todos';
  String _orden = 'recientes';
  int _mostrar = 0; // 0 = tamaño inicial según el ancho

  bool get _filtrando => _busqueda.text.trim().isNotEmpty || _chip != 'todos';

  @override
  void dispose() {
    _busqueda.dispose();
    super.dispose();
  }

  bool _coincideChip(Servicio s) {
    if (_chip == 'todos') return true;
    final cat = normalizar(s.categoria);
    return switch (_chip) {
      'tutorias' => cat.contains('tutoria'),
      'ensayos' => cat.contains('ensayo') || cat.contains('redaccion'),
      'proyectos' => cat.contains('proyecto'),
      'programacion' => cat.contains('programacion'),
      'diseno' => cat.contains('diseno'),
      'arriendo' => cat.contains('arriendo'),
      _ => true,
    };
  }

  List<Servicio> get _resultados {
    final q = normalizar(_busqueda.text);
    final lista = widget.servicios.where((s) {
      final texto = normalizar(
        '${s.titulo} ${s.descripcion} ${s.categoria} ${s.proveedor}',
      );
      return (q.isEmpty || texto.contains(q)) && _coincideChip(s);
    }).toList();
    lista.sort(switch (_orden) {
      'antiguos' => (a, b) => a.fechaPublicacion.compareTo(b.fechaPublicacion),
      'precio-menor' => (a, b) => a.precioHora.compareTo(b.precioHora),
      'precio-mayor' => (a, b) => b.precioHora.compareTo(a.precioHora),
      'rating-mayor' => (a, b) => b.estrellas.compareTo(a.estrellas),
      'rating-menor' => (a, b) => a.estrellas.compareTo(b.estrellas),
      _ => (a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion),
    });
    return lista;
  }

  List<Servicio> get _destacados =>
      (widget.servicios.where((s) => s.numResenas > 0).toList()
            ..sort((a, b) => b.estrellas.compareTo(a.estrellas)))
          .take(5)
          .toList();

  void _reiniciar() => setState(() => _mostrar = 0);

  void _limpiarFiltros() => setState(() {
    _busqueda.clear();
    _chip = 'todos';
    _mostrar = 0;
  });

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
    if (elegido != null && elegido != _orden) setState(() => _orden = elegido);
  }

  @override
  Widget build(BuildContext context) {
    final ancho = MediaQuery.sizeOf(context).width;
    final movil = ancho < Breakpoints.mobile;
    final margen = movil ? 16.0 : 24.0;
    final lote = movil ? 6 : 12;
    final mostrar = _mostrar == 0 ? lote : _mostrar;
    final resultados = _resultados;
    final visibles = resultados.take(mostrar).toList();
    final destacados = _filtrando ? const <Servicio>[] : _destacados;

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
              child: _Buscador(
                controller: _busqueda,
                onChanged: (_) => _reiniciar(),
              ),
            ),
            const SizedBox(height: 12),
            _FiltroCategorias(
              seleccionado: _chip,
              margen: margen,
              onChanged: (v) => setState(() {
                _chip = v;
                _mostrar = 0;
              }),
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
              texto: _filtrando
                  ? (resultados.length == 1
                        ? '1 resultado'
                        : '${resultados.length} resultados')
                  : 'Todos los servicios',
              margen: margen,
              accion: resultados.length > 1
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: margen),
              child: resultados.isEmpty
                  ? _SinResultados(
                      busqueda: _busqueda.text.trim(),
                      onLimpiar: _limpiarFiltros,
                    )
                  : RejillaServicios(
                      servicios: visibles,
                      onTapServicio: widget.onTapServicio,
                    ),
            ),
            if (resultados.length > visibles.length)
              Padding(
                padding: EdgeInsets.fromLTRB(margen, 20, margen, 0),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _mostrar = mostrar + lote),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.teal,
                      side: const BorderSide(color: AppColors.bordeCampo),
                      minimumSize: const Size(220, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Ver más servicios (${resultados.length - visibles.length})',
                      style: AppText.poppins(
                        14,
                        weight: FontWeight.w600,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

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

class _SinResultados extends StatelessWidget {
  final String busqueda;
  final VoidCallback onLimpiar;
  const _SinResultados({required this.busqueda, required this.onLimpiar});

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
          const Icon(
            Icons.search_off_rounded,
            size: 36,
            color: AppColors.texto2,
          ),
          const SizedBox(height: 12),
          Text(
            busqueda.isEmpty
                ? 'No hay servicios en esta categoría'
                : 'Sin resultados para "$busqueda"',
            textAlign: TextAlign.center,
            style: AppText.poppins(15.5, weight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            'Prueba con otra palabra o elige otra categoría.',
            textAlign: TextAlign.center,
            style: AppText.poppins(13.5, color: AppColors.texto2, height: 1.45),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onLimpiar,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.teal,
              side: const BorderSide(color: AppColors.bordeCampo),
              minimumSize: const Size(160, 44),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Ver todos',
              style: AppText.poppins(
                14,
                weight: FontWeight.w600,
                color: AppColors.teal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
