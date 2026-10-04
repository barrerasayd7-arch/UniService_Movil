import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../models/servicio.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../../widgets/section_backgrounds.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tarjeta_servicio.dart';

/// Sección #buscar del home: título, input, chips, orden, rejilla y
/// paginación con flechas + números + "Página X de Y".
class BusquedaHome extends StatefulWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;
  const BusquedaHome({
    super.key,
    required this.servicios,
    required this.onTapServicio,
  });

  @override
  State<BusquedaHome> createState() => _BusquedaHomeState();
}

class _BusquedaHomeState extends State<BusquedaHome> {
  String _query = '';
  String _chip = 'todos';
  String _orden = 'recientes';
  int _pagina = 1;

  bool _coincideChip(Servicio s) {
    if (_chip == 'todos') return true;
    final cat = normalizar(s.categoria);
    switch (_chip) {
      case 'tutorias':
        return cat.contains('tutoria');
      case 'ensayos':
        return cat.contains('ensayo') || cat.contains('redaccion');
      case 'proyectos':
        return cat.contains('proyecto');
      case 'programacion':
        return cat.contains('programacion');
      case 'diseno':
        return cat.contains('diseno');
      case 'arriendo':
        return cat.contains('arriendo');
    }
    return true;
  }

  List<Servicio> get _filtrados {
    final q = normalizar(_query);
    final lista = widget.servicios.where((s) {
      final texto = normalizar('${s.titulo} ${s.descripcion} ${s.categoria} ${s.proveedor}');
      return (q.isEmpty || texto.contains(q)) && _coincideChip(s);
    }).toList();

    switch (_orden) {
      case 'antiguos':
        lista.sort((a, b) => a.fechaPublicacion.compareTo(b.fechaPublicacion));
      case 'precio-menor':
        lista.sort((a, b) => a.precioHora.compareTo(b.precioHora));
      case 'precio-mayor':
        lista.sort((a, b) => b.precioHora.compareTo(a.precioHora));
      case 'rating-mayor':
        lista.sort((a, b) => b.estrellas.compareTo(a.estrellas));
      case 'rating-menor':
        lista.sort((a, b) => a.estrellas.compareTo(b.estrellas));
      default:
        lista.sort((a, b) => b.fechaPublicacion.compareTo(a.fechaPublicacion));
    }
    return lista;
  }

  /// Misma lógica de `generarPaginas()` de la web (null = "…").
  List<int?> _generarPaginas(int pagina, int total) {
    const maxVisible = 5;
    var inicio = math.max(1, pagina - maxVisible ~/ 2);
    final fin = math.min(total, inicio + maxVisible - 1);
    if (fin - inicio < maxVisible - 1) {
      inicio = math.max(1, fin - maxVisible + 1);
    }
    final out = <int?>[];
    if (inicio > 1) {
      out.add(1);
      if (inicio > 2) out.add(null);
    }
    for (var i = inicio; i <= fin; i++) {
      out.add(i);
    }
    if (fin < total) {
      if (fin < total - 1) out.add(null);
      out.add(total);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final porPagina = movil ? 3 : 8;
    final filtrados = _filtrados;
    final total = filtrados.isEmpty ? 0 : (filtrados.length / porPagina).ceil();
    final pagina = total == 0 ? 1 : math.min(_pagina, total);
    final visibles = filtrados.skip((pagina - 1) * porPagina).take(porPagina).toList();
    final h1 = movil ? 28.0 : 40.0;

    return SeccionFondo(
      oscura: true,
      fondo: FondoSeccion.grilla,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SectionLabel(text: 'Marketplace Universitario'),
                const SizedBox(height: 14),
                Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    style: AppText.serif(h1, height: 1.2),
                    children: [
                      const TextSpan(text: 'Todos los '),
                      WidgetSpan(
                        alignment: PlaceholderAlignment.baseline,
                        baseline: TextBaseline.alphabetic,
                        child: AcentoText('servicios', fontSize: h1),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
                _buscador(),
                const SizedBox(height: 24),
                _chips(),
                const SizedBox(height: 24),
                _barraOrden(filtrados.length),
                const SizedBox(height: 22),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey('$pagina-$_chip-$_orden-$_query'),
                    child: visibles.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.symmetric(vertical: 32),
                            child: Text(
                              'No se encontraron servicios con esos filtros.',
                              style: AppText.poppins(14, color: AppColors.texto2),
                            ),
                          )
                        : RejillaServicios(
                            servicios: visibles,
                            onTapServicio: widget.onTapServicio,
                          ),
                  ),
                ),
                if (total > 1) _paginacion(pagina, total),
                if (total > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      'Página $pagina de $total',
                      style: AppText.poppins(
                        13,
                        weight: FontWeight.w500,
                        color: AppColors.texto3,
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

  Widget _buscador() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 700),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde2),
        ),
        child: TextField(
          onChanged: (v) => setState(() {
            _query = v;
            _pagina = 1;
          }),
          cursorColor: AppColors.teal,
          style: AppText.poppins(14.4),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: '¿Qué necesitas hoy? (Ej: Álgebra, Logo, Habitación...)',
            hintStyle: AppText.poppins(14.4, color: AppColors.texto3),
            prefixIcon: const Icon(Icons.search, color: AppColors.teal, size: 20),
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _chips() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chipsCategoria)
          HoverBuilder(
            builder: (context, hover) {
              final activo = _chip == c.valor;
              return GestureDetector(
                onTap: () => setState(() {
                  _chip = c.valor;
                  _pagina = 1;
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: activo
                        ? AppColors.teal
                        : (hover ? AppColors.tealDim : AppColors.card),
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(
                      color: activo || hover ? AppColors.teal : AppColors.borde2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(c.icono, size: 14, color: activo ? AppColors.bg : AppColors.texto2),
                      const SizedBox(width: 6),
                      Text(
                        c.label,
                        style: AppText.poppins(
                          13,
                          weight: FontWeight.w600,
                          color: activo ? AppColors.bg : AppColors.texto2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _barraOrden(int cantidad) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      runSpacing: 10,
      spacing: 12,
      children: [
        Text.rich(
          TextSpan(
            style: AppText.poppins(13.5, color: AppColors.texto2),
            children: [
              const TextSpan(text: 'Resultados: '),
              TextSpan(
                text: '$cantidad',
                style: AppText.poppins(13.5, weight: FontWeight.w700),
              ),
            ],
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.borde2),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _orden,
                  dropdownColor: AppColors.card,
                  iconEnabledColor: AppColors.teal,
                  style: AppText.poppins(13),
                  items: [
                    for (final e in opcionesOrden.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setState(() {
                    _orden = v ?? 'recientes';
                    _pagina = 1;
                  }),
                ),
              ),
            ),
            const SizedBox(width: 8),
            HoverBuilder(
              builder: (context, hover) => GestureDetector(
                onTap: () => setState(() => _orden = paresOrden[_orden] ?? _orden),
                child: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: hover ? AppColors.tealDim : AppColors.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: hover ? AppColors.teal : AppColors.borde2),
                  ),
                  child: const Icon(Icons.swap_vert, size: 18, color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Paginación (.paginacion-container) ──
  Widget _paginacion(int actual, int total) {
    return Padding(
      padding: const EdgeInsets.only(top: 32),
      child: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          _flecha(Icons.chevron_left, actual > 1 ? () => setState(() => _pagina = actual - 1) : null),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 6,
            children: [
              for (final p in _generarPaginas(actual, total))
                if (p == null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      '…',
                      style: AppText.poppins(16, color: AppColors.texto3, spacing: 2),
                    ),
                  )
                else
                  _numero(p, p == actual, () => setState(() => _pagina = p)),
            ],
          ),
          _flecha(
            Icons.chevron_right,
            actual < total ? () => setState(() => _pagina = actual + 1) : null,
          ),
        ],
      ),
    );
  }

  Widget _flecha(IconData icono, VoidCallback? onTap) {
    return HoverBuilder(
      builder: (context, hover) {
        final h = hover && onTap != null;
        return Opacity(
          opacity: onTap == null ? 0.3 : 1,
          child: GestureDetector(
            onTap: onTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              transform: Matrix4.translationValues(0, h ? -2 : 0, 0),
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: h ? AppColors.teal : AppColors.bg3,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: h ? AppColors.teal : AppColors.borde2),
                boxShadow: h
                    ? [
                        BoxShadow(
                          color: AppColors.a(AppColors.teal, 0.3),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : const [],
              ),
              child: Icon(icono, size: 20, color: h ? AppColors.bg : AppColors.texto),
            ),
          ),
        );
      },
    );
  }

  Widget _numero(int n, bool activo, VoidCallback onTap) {
    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, activo || hover ? -2 : 0, 0),
          constraints: const BoxConstraints(minWidth: 40),
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: activo
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppColors.teal, AppColors.teal2],
                  )
                : null,
            color: activo ? null : (hover ? AppColors.tealDim : AppColors.bg2),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: activo
                  ? Colors.transparent
                  : (hover ? AppColors.teal : AppColors.borde),
            ),
            boxShadow: activo
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.35),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Text(
            '$n',
            style: AppText.poppins(
              14,
              weight: activo ? FontWeight.w700 : FontWeight.w500,
              color: activo
                  ? Colors.white
                  : (hover ? AppColors.teal : AppColors.texto2),
            ),
          ),
        ),
      ),
    );
  }
}
