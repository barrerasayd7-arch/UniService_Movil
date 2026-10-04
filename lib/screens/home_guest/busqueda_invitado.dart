import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../models/servicio.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import '../../widgets/section_backgrounds.dart';
import '../../widgets/section_label.dart';
import '../../widgets/tarjeta_servicio.dart';

/// Sección "Busca lo que necesitas" (BusquedaInvitado.jsx):
/// input, chips de categoría, orden, rejilla y paginación.
class BusquedaInvitado extends StatefulWidget {
  final List<Servicio> servicios;
  final void Function(Servicio) onTapServicio;
  const BusquedaInvitado({
    super.key,
    required this.servicios,
    required this.onTapServicio,
  });

  @override
  State<BusquedaInvitado> createState() => _BusquedaInvitadoState();
}

class _BusquedaInvitadoState extends State<BusquedaInvitado> {
  final _ctrl = TextEditingController();
  String _query = '';
  String _chip = 'todos';
  String _orden = 'recientes';
  int _pagina = 1;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= Breakpoints.mobile;
    final porPagina = movil ? 3 : 8;
    final filtrados = _filtrados;
    final total = filtrados.isEmpty ? 1 : (filtrados.length / porPagina).ceil();
    final pagina = _pagina.clamp(1, total).toInt();
    final visibles = filtrados.skip((pagina - 1) * porPagina).take(porPagina).toList();

    return SeccionFondo(
      fondo: FondoSeccion.grilla,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SectionLabel(text: 'Catálogo', icon: Icons.search),
                const SizedBox(height: 14),
                Text.rich(
                  textAlign: TextAlign.center,
                  TextSpan(
                    style: AppText.serif(movil ? 28 : 38.4, height: 1.2),
                    children: [
                      const TextSpan(text: 'Busca lo que '),
                      TextSpan(
                        text: 'necesitas',
                        style: AppText.serif(
                          movil ? 28 : 38.4,
                          color: AppColors.teal2,
                          style: FontStyle.italic,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                _buscador(),
                const SizedBox(height: 18),
                _chips(),
                const SizedBox(height: 22),
                _barraOrden(filtrados.length),
                const SizedBox(height: 22),
                if (visibles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      'No se encontraron servicios con esos filtros.',
                      style: AppText.poppins(14, color: AppColors.texto2),
                    ),
                  )
                else
                  RejillaServicios(servicios: visibles, onTapServicio: widget.onTapServicio),
                if (total > 1) ...[
                  const SizedBox(height: 28),
                  _paginacion(pagina, total),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buscador() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde2),
        ),
        child: TextField(
          controller: _ctrl,
          onChanged: (v) => setState(() {
            _query = v;
            _pagina = 1;
          }),
          cursorColor: AppColors.teal,
          style: AppText.poppins(14.4),
          decoration: InputDecoration(
            border: InputBorder.none,
            hintText: 'Buscar tutorías, ensayos, diseño...',
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
        Text(
          '$cantidad ${cantidad == 1 ? 'servicio encontrado' : 'servicios encontrados'}',
          style: AppText.poppins(13.5, color: AppColors.texto2),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Ordenar por:', style: AppText.poppins(13, color: AppColors.texto2)),
            const SizedBox(width: 8),
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
                  child: Icon(Icons.swap_vert, size: 18, color: AppColors.teal),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _paginacion(int actual, int total) {
    Widget boton(Widget child, VoidCallback? onTap, {bool activo = false}) {
      return GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: onTap == null ? 0.4 : 1,
          child: Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: activo ? AppColors.teal : AppColors.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: activo ? AppColors.teal : AppColors.borde2),
            ),
            child: child,
          ),
        ),
      );
    }

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 6,
      runSpacing: 6,
      children: [
        boton(
          const Icon(Icons.chevron_left, size: 20, color: AppColors.texto),
          actual > 1 ? () => setState(() => _pagina = actual - 1) : null,
        ),
        for (var i = 1; i <= total; i++)
          boton(
            Text(
              '$i',
              style: AppText.poppins(
                13,
                weight: FontWeight.w600,
                color: i == actual ? AppColors.bg : AppColors.texto,
              ),
            ),
            () => setState(() => _pagina = i),
            activo: i == actual,
          ),
        boton(
          const Icon(Icons.chevron_right, size: 20, color: AppColors.texto),
          actual < total ? () => setState(() => _pagina = actual + 1) : null,
        ),
      ],
    );
  }
}
