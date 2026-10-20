import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/admin_repository.dart';
import '../../models/admin_models.dart';
import 'admin_comun.dart';
import 'admin_widgets.dart' show horaCorta;

const _acciones = <String, (String, IconData)>{
  'login': ('Inició sesión', Icons.login_rounded),
  'suspender': ('Suspendió un usuario', Icons.block_rounded),
  'reactivar': ('Reactivó un usuario', Icons.check_circle_outline),
  'aprobar': ('Aprobó un servicio', Icons.check_rounded),
  'rechazar': ('Rechazó un servicio', Icons.close_rounded),
  'ocultar': ('Ocultó un servicio', Icons.visibility_off_outlined),
  'actualizar_reporte': ('Actualizó un reporte', Icons.flag_outlined),
};

/// Bitácora de acciones de los administradores.
class AdminActividadScreen extends StatefulWidget {
  const AdminActividadScreen({super.key});

  @override
  State<AdminActividadScreen> createState() => _AdminActividadScreenState();
}

class _AdminActividadScreenState extends State<AdminActividadScreen> {
  final _lista = GlobalKey<ListaAdminState<AdminAuditoria>>();
  String _entidad = '';

  Future<PaginaAdmin<AdminAuditoria>> _cargar(int page) =>
      AdminRepository.instance.auditoria(entidad: _entidad, page: page);

  void _filtrar(String v) {
    setState(() => _entidad = v);
    _lista.currentState?.recargar();
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      actual: 'actividad',
      titulo: 'Actividad',
      body: Column(
        children: [
          BarraFiltros(
            filtros: FiltroChips<String>(
              valor: _entidad,
              opciones: const [
                ('', 'Todo'),
                ('usuario', 'Usuarios'),
                ('servicio', 'Servicios'),
                ('reporte', 'Reportes'),
                ('admin', 'Sesiones'),
              ],
              onChanged: _filtrar,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListaAdmin<AdminAuditoria>(
              key: _lista,
              cargar: _cargar,
              vacio: 'No hay actividad registrada.',
              iconoVacio: Icons.history_rounded,
              itemBuilder: (_, a) => _ItemActividad(a: a),
            ),
          ),
        ],
      ),
    );
  }
}

class _ItemActividad extends StatelessWidget {
  final AdminAuditoria a;
  const _ItemActividad({required this.a});

  @override
  Widget build(BuildContext context) {
    final (texto, icono) =
        _acciones[a.accion] ??
        (a.accion.replaceAll('_', ' '), Icons.history_rounded);
    final cuando = a.fecha == null
        ? '—'
        : '${formatearFecha(a.fecha)} · ${horaCorta(a.fecha!)}';
    return TarjetaAdmin(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.a(AppColors.admin, 0.12),
              border: Border.all(color: AppColors.a(AppColors.admin, 0.3)),
            ),
            child: Icon(icono, size: 18, color: AppColors.admin),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  texto,
                  style: AppText.poppins(14.5, weight: FontWeight.w600),
                ),
                if (a.detalle != null && a.detalle!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    a.detalle!,
                    style: AppText.poppins(
                      13,
                      color: AppColors.texto2,
                      height: 1.4,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
                Text(
                  '${a.admin} · $cuando',
                  style: AppText.poppins(12, color: AppColors.texto3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
