import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/admin_repository.dart';
import '../../data/api_client.dart';
import '../../data/servicios_repository.dart';
import '../../models/admin_models.dart';
import '../../models/servicio_detalle.dart';
import '../login/auth_widgets.dart';
import 'admin_comun.dart';
import 'admin_widgets.dart';

/// Moderación de servicios. Con [soloPendientes] es la cola de revisión.
class AdminServiciosScreen extends StatefulWidget {
  final bool soloPendientes;
  const AdminServiciosScreen({super.key, this.soloPendientes = false});

  @override
  State<AdminServiciosScreen> createState() => _AdminServiciosScreenState();
}

class _AdminServiciosScreenState extends State<AdminServiciosScreen> {
  final _repo = AdminRepository.instance;
  final _buscador = TextEditingController();
  final _lista = GlobalKey<ListaAdminState<AdminServicio>>();
  Timer? _debounce;
  String _busqueda = '';
  late String _estado = widget.soloPendientes ? 'pendiente' : '';
  int? _accionando;

  @override
  void dispose() {
    _debounce?.cancel();
    _buscador.dispose();
    super.dispose();
  }

  Future<PaginaAdmin<AdminServicio>> _cargar(int page) =>
      _repo.servicios(estado: _estado, busqueda: _busqueda, page: page);

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

  Future<void> _aprobar(AdminServicio s) async {
    final ok = await confirmarAdmin(
      context,
      titulo: 'Aprobar servicio',
      mensaje: '¿Publicar "${s.titulo}"? El proveedor recibirá un correo.',
      confirmar: 'Aprobar',
    );
    if (!ok || !mounted) return;
    await _ejecutar(
      s.id,
      () => _repo.aprobarServicio(s.id),
      'Servicio aprobado',
    );
  }

  Future<void> _rechazar(AdminServicio s) async {
    final razon = await pedirMotivo(
      context,
      titulo: 'Rechazar servicio',
      mensaje:
          '"${s.titulo}" no se publicará y avisaremos al proveedor por correo. El motivo es opcional.',
      hint: 'Ej: Las imágenes no cumplen los requisitos',
      confirmar: 'Rechazar',
    );
    if (razon == null || !mounted) return;
    await _ejecutar(
      s.id,
      () => _repo.rechazarServicio(s.id, razon.isEmpty ? null : razon),
      'Servicio rechazado',
    );
  }

  Future<void> _ocultar(AdminServicio s) async {
    final motivo = await pedirMotivo(
      context,
      titulo: 'Ocultar servicio',
      mensaje:
          'Dejará de mostrarse y el proveedor podrá corregirlo y reenviarlo a revisión. Escribe el motivo.',
      hint: 'Ej: Incumple las normas de la plataforma',
      confirmar: 'Ocultar',
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
      s.id,
      () => _repo.ocultarServicio(s.id, motivo),
      'Servicio ocultado',
    );
  }

  Future<void> _ver(AdminServicio s) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => _DetalleServicio(servicio: s),
    );
    if (accion == null || !mounted) return;
    switch (accion) {
      case 'aprobar':
        await _aprobar(s);
      case 'rechazar':
        await _rechazar(s);
      case 'ocultar':
        await _ocultar(s);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pend = widget.soloPendientes;
    return AdminScaffold(
      actual: pend ? 'pendientes' : 'servicios',
      titulo: pend ? 'Pendientes' : 'Servicios',
      body: Column(
        children: [
          BarraFiltros(
            buscador: _buscador,
            hint: 'Buscar por título o proveedor',
            onBuscar: _buscar,
            filtros: pend
                ? null
                : FiltroChips<String>(
                    valor: _estado,
                    opciones: const [
                      ('', 'Todos'),
                      ('aprobado', 'Publicados'),
                      ('pendiente', 'Pendientes'),
                      ('pausado', 'Pausados'),
                      ('rechazado', 'Rechazados'),
                    ],
                    onChanged: _filtrar,
                  ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListaAdmin<AdminServicio>(
              key: _lista,
              cargar: _cargar,
              vacio: pend
                  ? 'No hay servicios por revisar. Todo está al día.'
                  : 'No se encontraron servicios.',
              iconoVacio: pend
                  ? Icons.check_circle_outline
                  : Icons.checklist_rounded,
              itemBuilder: (_, s) => _TarjetaServicio(
                s: s,
                ocupado: _accionando == s.id,
                bloqueado: _accionando != null,
                onVer: () => _ver(s),
                onAprobar: () => _aprobar(s),
                onRechazar: () => _rechazar(s),
                onOcultar: () => _ocultar(s),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaServicio extends StatelessWidget {
  final AdminServicio s;
  final bool ocupado;
  final bool bloqueado;
  final VoidCallback onVer, onAprobar, onRechazar, onOcultar;
  const _TarjetaServicio({
    required this.s,
    required this.ocupado,
    required this.bloqueado,
    required this.onVer,
    required this.onAprobar,
    required this.onRechazar,
    required this.onOcultar,
  });

  @override
  Widget build(BuildContext context) {
    final (etiqueta, color) = estadoServicio(s.estado);
    final icono = iconosPorCategoria[s.categoria] ?? iconoPorDefecto;
    final pendiente = s.estado == 'pendiente';
    final publicado = s.estado == 'aprobado' || s.estado == 'pausado';

    return TarjetaAdmin(
      acento: color,
      onTap: onVer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: s.imagen == null
                      ? ColoredBox(
                          color: AppColors.bg3,
                          child: Icon(icono, color: AppColors.texto2),
                        )
                      : Image.network(
                          s.imagen!,
                          fit: BoxFit.cover,
                          cacheWidth: 160,
                          errorBuilder: (_, _, _) => const ColoredBox(
                            color: AppColors.bg3,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: AppColors.texto3,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.titulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(
                        15,
                        weight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${s.proveedor} · ${etiquetaCategoria(s.categoria)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.poppins(12.5, color: AppColors.texto2),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${formatearPrecio(s.precio)} ${unidadesPrecio[s.unidadPrecio] ?? ''} · ${formatearFecha(s.fechaPublicacion)}',
                      style: AppText.poppins(12.5, color: AppColors.texto2),
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
              PildoraEstado(texto: etiqueta, color: color),
              if (s.reportes > 0)
                PildoraEstado(
                  texto:
                      '${s.reportes} ${s.reportes == 1 ? 'reporte' : 'reportes'}',
                  color: AppColors.errorTexto,
                ),
              if (!s.proveedorActivo)
                const PildoraEstado(
                  texto: 'Proveedor suspendido',
                  color: AppColors.errorTexto,
                ),
            ],
          ),
          if (s.estado == 'rechazado' &&
              (s.motivoRechazo?.isNotEmpty ?? false)) ...[
            const SizedBox(height: 8),
            Text(
              'Motivo: ${s.motivoRechazo}',
              style: AppText.poppins(
                12.5,
                color: AppColors.texto2,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              BotonAdmin(
                label: 'Ver',
                icono: Icons.visibility_outlined,
                color: AppColors.texto2,
                onTap: bloqueado ? null : onVer,
              ),
              if (pendiente) ...[
                BotonAdmin(
                  label: 'Rechazar',
                  icono: Icons.close_rounded,
                  color: AppColors.errorTexto,
                  onTap: bloqueado ? null : onRechazar,
                ),
                BotonAdmin(
                  label: 'Aprobar',
                  icono: Icons.check_rounded,
                  color: AppColors.verificado,
                  relleno: true,
                  cargando: ocupado,
                  onTap: bloqueado ? null : onAprobar,
                ),
              ],
              if (publicado)
                BotonAdmin(
                  label: 'Ocultar',
                  icono: Icons.visibility_off_outlined,
                  color: AppColors.amarillo,
                  cargando: ocupado,
                  onTap: bloqueado ? null : onOcultar,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hoja con imágenes y datos del servicio (usa `GET /api/servicios/{id}`, que el admin
/// puede ver aunque no esté publicado). Devuelve 'aprobar' | 'rechazar' | 'ocultar'.
class _DetalleServicio extends StatefulWidget {
  final AdminServicio servicio;
  const _DetalleServicio({required this.servicio});

  @override
  State<_DetalleServicio> createState() => _DetalleServicioState();
}

class _DetalleServicioState extends State<_DetalleServicio> {
  ServicioDetalle? _d;
  String? _error;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await ServiciosRepository.instance.detalle(widget.servicio.id);
      if (!mounted) return;
      setState(() => _d = d);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Widget _cuerpo() {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: AppColors.admin,
          ),
        ),
      );
    }
    final d = _d;
    if (d == null) {
      return Column(
        children: [
          Text(
            _error ?? 'No pudimos cargar el servicio.',
            textAlign: TextAlign.center,
            style: AppText.poppins(14, color: AppColors.texto2),
          ),
          AuthTextButton(
            label: 'Reintentar',
            color: AppColors.admin,
            onTap: _cargar,
          ),
        ],
      );
    }
    final sv = d.servicio;
    final imgs = d.imagenes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (imgs.isEmpty)
          Text(
            'Este servicio no tiene imágenes.',
            style: AppText.poppins(13.5, color: AppColors.texto2),
          )
        else
          SizedBox(
            height: 110,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: imgs.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (ctx, i) {
                final url = imgs[i].url;
                return Semantics(
                  button: true,
                  label: 'Ver imagen ${i + 1} de ${imgs.length}',
                  child: GestureDetector(
                    onTap: url == null ? null : () => verImagenAdmin(ctx, url),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 110,
                        height: 110,
                        child: url == null
                            ? const ColoredBox(color: AppColors.bg3)
                            : Image.network(
                                url,
                                fit: BoxFit.cover,
                                cacheWidth: 260,
                                errorBuilder: (_, _, _) => const ColoredBox(
                                  color: AppColors.bg3,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: AppColors.texto3,
                                  ),
                                ),
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.bg2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borde),
          ),
          child: Text(
            sv.descripcion.isEmpty ? 'Sin descripción.' : sv.descripcion,
            style: AppText.poppins(14, height: 1.55),
          ),
        ),
        const SizedBox(height: 10),
        FilaDatoAdmin(
          'Precio',
          '${formatearPrecio(sv.precio)} ${unidadesPrecio[sv.unidadPrecio] ?? ''}'
              .trim(),
        ),
        FilaDatoAdmin('Categoría', sv.categoria),
        FilaDatoAdmin('Modalidad', modalidades[sv.modalidad] ?? sv.modalidad),
        FilaDatoAdmin(
          'Disponibilidad',
          disponibilidades[sv.disponibilidad] ?? sv.disponibilidad,
        ),
        FilaDatoAdmin(
          'Proveedor',
          widget.servicio.correoProveedor == null
              ? sv.proveedor
              : '${sv.proveedor}\n${widget.servicio.correoProveedor}',
        ),
        FilaDatoAdmin('Universidad', d.universidadTexto),
        if (d.contacto != null) FilaDatoAdmin('Contacto', d.contacto!),
        if (d.direccion != null) FilaDatoAdmin('Dirección', d.direccion!),
        FilaDatoAdmin('Publicado', formatearFecha(sv.fechaPublicacion)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.servicio;
    final (etiqueta, color) = estadoServicio(s.estado);
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(s.titulo, style: AppText.serif(24, height: 1.15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PildoraEstado(texto: etiqueta, color: color),
                  if (s.reportes > 0)
                    PildoraEstado(
                      texto:
                          '${s.reportes} ${s.reportes == 1 ? 'reporte' : 'reportes'}',
                      color: AppColors.errorTexto,
                    ),
                ],
              ),
              if (s.estado == 'rechazado' &&
                  (s.motivoRechazo?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                Text(
                  'Motivo: ${s.motivoRechazo}',
                  style: AppText.poppins(
                    13.5,
                    color: AppColors.texto2,
                    height: 1.4,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _cuerpo(),
              if (s.estado == 'pendiente') ...[
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: BotonAdmin(
                        label: 'Rechazar',
                        icono: Icons.close_rounded,
                        color: AppColors.errorTexto,
                        expandido: true,
                        onTap: () => Navigator.of(context).pop('rechazar'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: BotonAdmin(
                        label: 'Aprobar',
                        icono: Icons.check_rounded,
                        color: AppColors.verificado,
                        relleno: true,
                        expandido: true,
                        onTap: () => Navigator.of(context).pop('aprobar'),
                      ),
                    ),
                  ],
                ),
              ] else if (s.estado == 'aprobado' || s.estado == 'pausado') ...[
                const SizedBox(height: 16),
                BotonAdmin(
                  label: 'Ocultar servicio',
                  icono: Icons.visibility_off_outlined,
                  color: AppColors.amarillo,
                  expandido: true,
                  onTap: () => Navigator.of(context).pop('ocultar'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
