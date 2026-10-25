// Archivo: mis_servicios_screen.dart
// Responsabilidad: lista de servicios propios en cualquier estado y sus acciones.
// Se usa desde: ruta '/mis-servicios' (navbar, detalle y tras publicar).

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/servicios_repository.dart';
import '../../models/mi_servicio.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;

/// Servicios propios en cualquier estado (`GET /api/servicios/mios`), con sus acciones.
class MisServiciosScreen extends StatefulWidget {
  final ServiciosRepository? repositorio;
  const MisServiciosScreen({super.key, this.repositorio});

  @override
  State<MisServiciosScreen> createState() => _MisServiciosScreenState();
}

class _MisServiciosScreenState extends State<MisServiciosScreen> {
  late final ServiciosRepository _repo =
      widget.repositorio ?? ServiciosRepository.instance;
  List<MiServicio>? _servicios;
  String? _error;
  final Set<int> _ocupados = {}; // ids con pausa/reanudación/borrado en curso

  @override
  void initState() {
    super.initState();
    _repo.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    _repo.cambios.removeListener(_cargar);
    super.dispose();
  }

  /// Trae `GET /api/servicios/mios`; también reacciona a `_repo.cambios`.
  Future<void> _cargar() async {
    try {
      final lista = await _repo.mios();
      if (mounted) {
        setState(() {
          _servicios = lista;
          _error = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.mensaje);
    }
  }

  /// Ejecuta una acción de la tarjeta y bloquea sus controles mientras dura.
  Future<void> _accion(MiServicio s, Future<void> Function() hacer) async {
    setState(() => _ocupados.add(s.id));
    try {
      await hacer();
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _ocupados.remove(s.id));
    }
  }

  /// Hoja de opciones: ver, editar, pausar/reanudar y eliminar según el estado.
  Future<void> _opciones(MiServicio s) async {
    final opcion = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                s.titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: AppText.poppins(15, weight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.visibility_outlined),
              title: const Text('Ver como lo ven los demás'),
              onTap: () => Navigator.of(ctx).pop('ver'),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Editar'),
              subtitle: const Text('Vuelve a revisión al guardar'),
              onTap: () => Navigator.of(ctx).pop('editar'),
            ),
            if (s.puedePausar)
              ListTile(
                leading: const Icon(Icons.pause_circle_outline),
                title: const Text('Pausar'),
                subtitle: const Text('Deja de aparecer en las búsquedas'),
                onTap: () => Navigator.of(ctx).pop('pausar'),
              ),
            if (s.puedeReanudar)
              ListTile(
                leading: const Icon(Icons.play_circle_outline),
                title: const Text('Reanudar'),
                subtitle: const Text('Vuelve a mostrarse sin nueva revisión'),
                onTap: () => Navigator.of(ctx).pop('reanudar'),
              ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColors.errorTexto,
              ),
              title: const Text(
                'Eliminar',
                style: TextStyle(color: AppColors.errorTexto),
              ),
              onTap: () => Navigator.of(ctx).pop('eliminar'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || opcion == null) return;
    final nav = Navigator.of(context);
    switch (opcion) {
      case 'ver':
        nav.pushNamed('/servicio', arguments: s.id);
      case 'editar':
        nav.pushNamed('/publicar', arguments: s.id);
      case 'pausar':
        _accion(s, () => _repo.pausar(s.id, pausado: true));
      case 'reanudar':
        _accion(s, () => _repo.pausar(s.id, pausado: false));
      case 'eliminar':
        _confirmarEliminar(s);
    }
  }

  /// El borrado es irreversible: arrastra fotos, solicitudes y reseñas.
  Future<void> _confirmarEliminar(MiServicio s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('¿Eliminar este servicio?', style: AppText.serif(22)),
        content: Text(
          'Se borrarán también sus fotos, solicitudes y reseñas. No se puede deshacer.',
          style: AppText.poppins(14, color: AppColors.texto2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorTexto),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) await _accion(s, () => _repo.eliminar(s.id));
  }

  @override
  Widget build(BuildContext context) {
    final lista = _servicios;
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        surfaceTintColor: Colors.transparent,
        title: Text('Mis servicios', style: AppText.serif(22)),
        actions: [
          IconButton(
            tooltip: 'Solicitudes',
            icon: const Icon(Icons.inbox_outlined),
            onPressed: () => Navigator.of(context).pushNamed('/solicitudes'),
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borde),
        ),
      ),
      floatingActionButton: lista == null || lista.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => Navigator.of(context).pushNamed('/publicar'),
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.bg,
              icon: const Icon(Icons.add),
              label: Text(
                'Publicar',
                style: AppText.poppins(
                  15,
                  weight: FontWeight.w700,
                  color: AppColors.bg,
                ),
              ),
            ),
      body: RefreshIndicator(
        color: AppColors.teal,
        backgroundColor: AppColors.card,
        onRefresh: _cargar,
        child: lista == null
            ? (_error == null
                  ? const Center(
                      child: CircularProgressIndicator(color: AppColors.teal),
                    )
                  : _Vacio(
                      icono: Icons.cloud_off_rounded,
                      titulo: 'No pudimos cargar tus servicios',
                      texto: _error!,
                      boton: 'Reintentar',
                      onBoton: _cargar,
                    ))
            : lista.isEmpty
            ? _Vacio(
                icono: Icons.storefront_outlined,
                titulo: 'Aún no publicas servicios',
                texto:
                    'Ofrece tutorías, diseño, programación o una habitación. Te avisamos cuando lo aprueben.',
                boton: 'Publicar mi primer servicio',
                onBoton: () => Navigator.of(context).pushNamed('/publicar'),
              )
            : ListView.separated(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: lista.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final s = lista[i];
                  return Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _TarjetaMiServicio(
                        servicio: s,
                        ocupado: _ocupados.contains(s.id),
                        onTap: () => Navigator.of(
                          context,
                        ).pushNamed('/servicio', arguments: s.id),
                        onOpciones: () => _opciones(s),
                        onSolicitudes: () =>
                            Navigator.of(context).pushNamed('/solicitudes'),
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

/// Tarjeta de un servicio propio: estado, precio, reseñas y avisos pendientes.
class _TarjetaMiServicio extends StatelessWidget {
  final MiServicio servicio;
  final bool ocupado;
  final VoidCallback onTap;
  final VoidCallback onOpciones;
  final VoidCallback onSolicitudes;
  const _TarjetaMiServicio({
    required this.servicio,
    required this.ocupado,
    required this.onTap,
    required this.onOpciones,
    required this.onSolicitudes,
  });

  @override
  Widget build(BuildContext context) {
    final s = servicio;
    final (etiqueta, color) = estadoServicio(s.estado);
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: ocupado ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.borde),
          ),
          padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Miniatura(url: s.imagenUrl, categoria: s.categoria),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Chip(texto: etiqueta, color: color),
                        const SizedBox(height: 6),
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
                        const SizedBox(height: 4),
                        Text(
                          '${textoPrecio(s.precio, s.unidadPrecio)} · ${etiquetaCategoria(s.categoria)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(13, color: AppColors.texto2),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(
                              Icons.star_rounded,
                              size: 15,
                              color: AppColors.estrella,
                            ),
                            const SizedBox(width: 3),
                            Text(
                              s.numResenas == 0
                                  ? 'Sin reseñas'
                                  : '${formatearDecimal(s.promedio)} (${s.numResenas})',
                              style: AppText.poppins(
                                12.5,
                                color: AppColors.texto2,
                              ),
                            ),
                            if (s.numImagenes == 0) ...[
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.hide_image_outlined,
                                size: 15,
                                color: AppColors.texto3,
                              ),
                              const SizedBox(width: 3),
                              Text(
                                'Sin fotos',
                                style: AppText.poppins(
                                  12.5,
                                  color: AppColors.texto3,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  ocupado
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.teal,
                            ),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Opciones',
                          onPressed: onOpciones,
                          icon: const Icon(
                            Icons.more_vert,
                            color: AppColors.texto2,
                          ),
                        ),
                ],
              ),
              if (s.estado == 'rechazado' &&
                  (s.motivoRechazo?.isNotEmpty ?? false))
                Container(
                  margin: const EdgeInsets.only(top: 10, right: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.a(AppColors.errorTexto, 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    'Motivo: ${s.motivoRechazo}. Edítalo para enviarlo de nuevo a revisión.',
                    style: AppText.poppins(
                      12.5,
                      color: AppColors.texto2,
                      height: 1.4,
                    ),
                  ),
                ),
              if (s.solicitudesPendientes > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8, right: 8),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: onSolicitudes,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.amarillo,
                        minimumSize: const Size(48, 40),
                      ),
                      icon: const Icon(Icons.mark_email_unread_outlined, size: 18),
                      label: Text(
                        s.solicitudesPendientes == 1
                            ? '1 solicitud por responder'
                            : '${s.solicitudesPendientes} solicitudes por responder',
                        style: AppText.poppins(
                          13,
                          weight: FontWeight.w600,
                          color: AppColors.amarillo,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Portada del servicio o el icono de su categoría si no tiene fotos.
class _Miniatura extends StatelessWidget {
  final String? url;
  final String categoria;
  const _Miniatura({required this.url, required this.categoria});

  @override
  Widget build(BuildContext context) {
    const lado = 76.0;
    final color = coloresCategoria[categoria]?.color ?? AppColors.teal;
    final respaldo = ColoredBox(
      color: AppColors.a(color, 0.15),
      child: Icon(
        iconosPorCategoria[categoria] ?? iconoPorDefecto,
        color: color,
        size: 30,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: lado,
        height: lado,
        child: url == null
            ? respaldo
            : Image.network(
                url!,
                fit: BoxFit.cover,
                cacheWidth: (lado * MediaQuery.devicePixelRatioOf(context))
                    .round(),
                errorBuilder: (_, _, _) => respaldo,
              ),
      ),
    );
  }
}

/// Etiqueta compacta del estado del servicio.
class _Chip extends StatelessWidget {
  final String texto;
  final Color color;
  const _Chip({required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.a(color, 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.a(color, 0.4)),
      ),
      child: Text(
        texto,
        style: AppText.poppins(11.5, weight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Estado vacío o de error con un botón de acción (publicar o reintentar).
class _Vacio extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  final String boton;
  final VoidCallback onBoton;
  const _Vacio({
    required this.icono,
    required this.titulo,
    required this.texto,
    required this.boton,
    required this.onBoton,
  });

  @override
  Widget build(BuildContext context) {
    // ListView para que funcione "deslizar para recargar".
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
      children: [
        Icon(icono, size: 48, color: AppColors.texto2),
        const SizedBox(height: 16),
        Text(titulo, textAlign: TextAlign.center, style: AppText.serif(24)),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: AppText.poppins(14, color: AppColors.texto2, height: 1.5),
        ),
        const SizedBox(height: 24),
        Center(
          child: FilledButton(
            onPressed: onBoton,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              foregroundColor: AppColors.bg,
              minimumSize: const Size(220, 50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              boton,
              style: AppText.poppins(
                15,
                weight: FontWeight.w700,
                color: AppColors.bg,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
