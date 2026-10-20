import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/servicios_repository.dart';
import 'admin_comun.dart';
import '../login/auth_widgets.dart';

/// Categorías (ids fijos de `categorias.dart`) con cuántos servicios publicados tiene cada una.
class AdminCategoriasScreen extends StatefulWidget {
  const AdminCategoriasScreen({super.key});

  @override
  State<AdminCategoriasScreen> createState() => _AdminCategoriasScreenState();
}

class _AdminCategoriasScreenState extends State<AdminCategoriasScreen> {
  Map<int, int>? _conteos;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final repo = ServiciosRepository.instance;
      final paginas = await Future.wait([
        for (final (id, _) in categoriasServicio)
          repo.listar(categoria: id, porPagina: 1),
      ]);
      if (!mounted) return;
      setState(() {
        _conteos = {
          for (var i = 0; i < categoriasServicio.length; i++)
            categoriasServicio[i].$1: paginas[i].total,
        };
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      actual: 'categorias',
      titulo: 'Categorías',
      body: RefreshIndicator(
        color: AppColors.admin,
        backgroundColor: AppColors.card,
        onRefresh: _cargar,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(
                        'Servicios publicados por categoría',
                        style: AppText.poppins(
                          13,
                          weight: FontWeight.w600,
                          color: AppColors.texto2,
                          spacing: 0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _cuerpo(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cuerpo() {
    if (_error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthAviso(mensaje: _error),
          AuthPrimaryButton(
            label: 'Reintentar',
            color: AppColors.admin,
            colorHover: AppColors.adminHover,
            onTap: _cargar,
          ),
        ],
      );
    }
    return LayoutBuilder(
      builder: (context, c) {
        final columnas = c.maxWidth >= 560 ? 3 : 2;
        const espacio = 12.0;
        final ancho = (c.maxWidth - espacio * (columnas - 1)) / columnas;
        return Wrap(
          spacing: espacio,
          runSpacing: espacio,
          children: [
            for (final (id, nombre) in categoriasServicio)
              SizedBox(
                width: ancho,
                child: _TarjetaCategoria(nombre: nombre, valor: _conteos?[id]),
              ),
          ],
        );
      },
    );
  }
}

class _TarjetaCategoria extends StatelessWidget {
  final String nombre;
  final int? valor; // null = cargando
  const _TarjetaCategoria({required this.nombre, required this.valor});

  @override
  Widget build(BuildContext context) {
    final c =
        coloresCategoria[nombre] ??
        const CategoriaColor(Color(0x1A94A3B8), Color(0xFF94A3B8));
    return Semantics(
      label: valor == null
          ? '$nombre, cargando'
          : '$nombre: $valor servicios publicados',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.borde),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: c.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                iconosPorCategoria[nombre] ?? iconoPorDefecto,
                size: 20,
                color: c.color,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 38,
              child: valor == null
                  ? Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 48,
                        height: 22,
                        decoration: BoxDecoration(
                          color: AppColors.bg3,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    )
                  : Text('$valor', style: AppText.serif(32, height: 1.1)),
            ),
            const SizedBox(height: 2),
            Text(
              nombre,
              style: AppText.poppins(
                13.5,
                color: AppColors.texto2,
                height: 1.3,
              ),
            ),
            Text(
              'publicados',
              style: AppText.poppins(12, color: AppColors.texto3),
            ),
          ],
        ),
      ),
    );
  }
}
