// Archivo: admin_usuarios_screen.dart
// Responsabilidad: listar y moderar cuentas: buscar, filtrar por estado, suspender con motivo
//   y reactivar. Las cuentas admin no se pueden suspender desde aquí.
// Se usa desde: la sección "Usuarios" del panel (ruta '/admin/usuarios').

import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/admin_repository.dart';
import '../../models/admin_models.dart';
import '../../models/servicio_detalle.dart' show iniciales;
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'admin_comun.dart';
import 'admin_widgets.dart';

/// Usuarios: búsqueda, filtro por estado, suspender (con motivo) y reactivar.
class AdminUsuariosScreen extends StatefulWidget {
  const AdminUsuariosScreen({super.key});

  @override
  State<AdminUsuariosScreen> createState() => _AdminUsuariosScreenState();
}

class _AdminUsuariosScreenState extends State<AdminUsuariosScreen> {
  final _repo = AdminRepository.instance;
  final _buscador = TextEditingController();
  final _lista = GlobalKey<ListaAdminState<AdminUsuario>>();
  Timer? _debounce;
  String _busqueda = '';
  String _estado = '';
  int? _accionando; // id del usuario cuya acción está en curso

  @override
  void dispose() {
    _debounce?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Future<PaginaAdmin<AdminUsuario>> _cargar(int page) =>
      _repo.usuarios(busqueda: _busqueda, estado: _estado, page: page);

  // Espera 400 ms tras escribir para no consultar en cada tecla.
  void _buscar(String t) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _busqueda = t;
      _lista.currentState?.recargar();
    });
  }

  void _filtrar(String v) {
    setState(() => _estado = v);
    _lista.currentState?.recargar();
  }

  // Comparte el estado "ocupado" y refresca en silencio para no parpadear la lista.
  Future<void> _ejecutar(
    int id,
    Future<void> Function() accion,
    String exito,
  ) async {
    setState(() => _accionando = id);
    final ok = await accionAdmin(context, accion, exito: exito);
    if (!mounted) return;
    setState(() => _accionando = null);
    if (ok) _lista.currentState?.recargar(silencioso: true);
  }

  // La suspensión queda registrada a nombre del admin: exige motivo de 5+ caracteres.
  Future<void> _suspender(AdminUsuario u) async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Suspender cuenta',
      mensaje:
          '${u.nombre} perderá el acceso hasta que la reactives. Escribe el motivo; queda registrado a tu nombre.',
      hint: 'Ej: Acoso a otros usuarios',
      confirmar: 'Suspender',
    );
    if (motivo == null || !mounted) return;
    if (motivo.length < 5) {
      await mostrarNotificacion(
        context,
        'El motivo debe tener al menos 5 caracteres.',
      );
      return;
    }
    await _ejecutar(
      u.id,
      () => _repo.suspenderUsuario(u.id, motivo),
      'Cuenta suspendida',
    );
  }

  // Reactivar solo requiere confirmación y devuelve el acceso de inmediato.
  Future<void> _reactivar(AdminUsuario u) async {
    final ok = await confirmarAdmin(
      context,
      titulo: 'Reactivar cuenta',
      mensaje:
          '¿Reactivar la cuenta de ${u.nombre}? Podrá volver a iniciar sesión.',
      confirmar: 'Reactivar',
    );
    if (!ok || !mounted) return;
    await _ejecutar(
      u.id,
      () => _repo.reactivarUsuario(u.id),
      'Cuenta reactivada',
    );
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      actual: 'usuarios',
      titulo: 'Usuarios',
      body: Column(
        children: [
          BarraFiltros(
            buscador: _buscador,
            hint: 'Buscar por nombre o correo',
            onBuscar: _buscar,
            filtros: FiltroChips<String>(
              valor: _estado,
              opciones: const [
                ('', 'Todos'),
                ('activos', 'Activos'),
                ('suspendidos', 'Suspendidos'),
              ],
              onChanged: _filtrar,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListaAdmin<AdminUsuario>(
              key: _lista,
              cargar: _cargar,
              vacio: 'No se encontraron usuarios.',
              iconoVacio: Icons.people_outline_rounded,
              itemBuilder: (_, u) => _TarjetaUsuario(
                u: u,
                ocupado: _accionando == u.id,
                onSuspender: _accionando != null ? null : () => _suspender(u),
                onReactivar: _accionando != null ? null : () => _reactivar(u),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fila de usuario con iniciales, estado, actividad y el botón que corresponda.
class _TarjetaUsuario extends StatelessWidget {
  final AdminUsuario u;
  final bool ocupado;
  final VoidCallback? onSuspender;
  final VoidCallback? onReactivar;
  const _TarjetaUsuario({
    required this.u,
    required this.ocupado,
    required this.onSuspender,
    required this.onReactivar,
  });

  @override
  Widget build(BuildContext context) {
    final servicios =
        '${u.totalServicios} ${u.totalServicios == 1 ? 'servicio' : 'servicios'}';
    final reportes =
        '${u.reportesRecibidos} ${u.reportesRecibidos == 1 ? 'reporte recibido' : 'reportes recibidos'}';
    return TarjetaAdmin(
      acento: u.activa ? null : AppColors.errorTexto,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.a(AppColors.admin, 0.12),
                  border: Border.all(color: AppColors.a(AppColors.admin, 0.3)),
                ),
                child: Text(
                  iniciales(u.nombre),
                  style: AppText.poppins(
                    14,
                    weight: FontWeight.w700,
                    color: AppColors.admin,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      u.nombre.isEmpty ? 'Sin nombre' : u.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(15, weight: FontWeight.w600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      u.correo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(13, color: AppColors.texto2),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (u.esAdmin)
                const PildoraEstado(
                  texto: 'Administrador',
                  color: AppColors.admin,
                ),
              PildoraEstado(
                texto: u.activa ? 'Activa' : 'Suspendida',
                color: u.activa ? AppColors.verificado : AppColors.errorTexto,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '$servicios · $reportes · Registro: ${formatearFecha(u.fechaRegistro)}',
            style: AppText.poppins(12.5, color: AppColors.texto2, height: 1.4),
          ),
          if (!u.activa && (u.motivoSuspension?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo: ${u.motivoSuspension}',
              style: AppText.poppins(12.5, height: 1.4),
            ),
          ],
          if (!u.esAdmin) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: u.activa
                  ? BotonAdmin(
                      label: 'Suspender',
                      icono: Icons.block_rounded,
                      color: AppColors.amarillo,
                      cargando: ocupado,
                      onTap: onSuspender,
                    )
                  : BotonAdmin(
                      label: 'Reactivar',
                      icono: Icons.check_circle_outline,
                      color: AppColors.verificado,
                      cargando: ocupado,
                      onTap: onReactivar,
                    ),
            ),
          ],
        ],
      ),
    );
  }
}
