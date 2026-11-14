// Archivo: solicitudes_screen.dart
// Responsabilidad: bandeja de solicitudes recibidas y enviadas, con sus acciones.
// Se usa desde: ruta '/solicitudes' (navbar, Mis servicios y detalle).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../../models/chat.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;
import '../chat/chat_session.dart';

/// Solicitudes recibidas (como proveedor) y enviadas (como cliente).
class SolicitudesScreen extends StatefulWidget {
  /// 0 = recibidas, 1 = enviadas.
  final int pestanaInicial;
  final SolicitudesRepository? repositorio;
  const SolicitudesScreen({
    super.key,
    this.pestanaInicial = 0,
    this.repositorio,
  });

  @override
  State<SolicitudesScreen> createState() => _SolicitudesScreenState();
}

class _SolicitudesScreenState extends State<SolicitudesScreen>
    with WidgetsBindingObserver, ChatVisible<SolicitudesScreen> {
  late final SolicitudesRepository _repo =
      widget.repositorio ?? SolicitudesRepository.instance;
  List<Solicitud>? _recibidas;
  List<Solicitud>? _enviadas;
  String? _errorRecibidas;
  String? _errorEnviadas;
  String? _filtroRecibidas;
  String? _filtroEnviadas;
  int _cargaRecibidas = 0;
  int _cargaEnviadas = 0;
  final Set<int> _ocupadas =
      {}; // ids con una acción en curso (spinner por tarjeta)

  @override
  void initState() {
    super.initState();
    iniciarVisibilidad();
    _repo.cambios.addListener(_cargar);
    _cargar();
  }

  @override
  void dispose() {
    terminarVisibilidad();
    _repo.cambios.removeListener(_cargar);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    observarRuta();
  }

  @override
  void refrescarChat() => _cargar();

  /// Recarga ambas bandejas en paralelo; también se dispara al cambiar el repo.
  Future<void> _cargar() =>
      Future.wait([_cargarRecibidas(), _cargarEnviadas()]);

  Future<void> _cargarRecibidas() async {
    final carga = ++_cargaRecibidas;
    try {
      final l = await _repo.recibidas(estado: _filtroRecibidas);
      if (mounted && carga == _cargaRecibidas) {
        setState(() {
          _recibidas = l;
          _errorRecibidas = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && carga == _cargaRecibidas) {
        setState(() => _errorRecibidas = e.mensaje);
      }
    }
  }

  Future<void> _cargarEnviadas() async {
    final carga = ++_cargaEnviadas;
    try {
      final l = await _repo.enviadas(estado: _filtroEnviadas);
      if (mounted && carga == _cargaEnviadas) {
        setState(() {
          _enviadas = l;
          _errorEnviadas = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted && carga == _cargaEnviadas) {
        setState(() => _errorEnviadas = e.mensaje);
      }
    }
  }

  /// Ejecuta una acción de la tarjeta, la marca como ocupada y, si falla,
  /// recarga porque el estado pudo cambiar desde otro dispositivo.
  Future<void> _hacer(
    Solicitud s,
    Future<void> Function() accion,
    String exito,
  ) async {
    setState(() => _ocupadas.add(s.id));
    try {
      await accion();
      if (mounted) mostrarNotificacion(context, exito, exito: true);
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
      _cargar(); // el estado pudo cambiar en el otro teléfono
    } finally {
      if (mounted) setState(() => _ocupadas.remove(s.id));
    }
  }

  /// Confirma el importe vigente sin cambiar el presupuesto original.
  Future<void> _aceptar(Solicitud s) => _confirmar(
    s,
    titulo: 'Aceptar solicitud',
    texto: s.precioAcordado == null
        ? '¿Confirmas el servicio solicitado por ${s.cliente.nombre}?'
        : 'Confirmarás el servicio por ${formatearPrecio(s.precioAcordado!)}${s.estadoContraoferta == 'aceptada' ? ', precio que el cliente aceptó' : ', presupuesto del cliente'}.',
    boton: 'Aceptar',
    accion: () => _repo.aceptar(s.id, version: s.versionContraoferta),
    exito: 'Solicitud aceptada. Avisamos al cliente.',
  );

  Future<void> _contraofertar(Solicitud s) async {
    final precio = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoContraoferta(solicitud: s),
    );
    if (precio == null || !mounted) return;
    await _hacer(
      s,
      () => _repo.contraofertar(s.id, precio, version: s.versionContraoferta),
      'Contraoferta enviada. Espera la respuesta del cliente.',
    );
  }

  Future<void> _responderContraoferta(Solicitud s, bool aceptar) => _confirmar(
    s,
    titulo: aceptar ? 'Aceptar contraoferta' : 'Rechazar contraoferta',
    texto: aceptar
        ? 'Aceptarás el precio de ${formatearPrecio(s.contraoferta!)}. Después, el proveedor deberá confirmar el servicio.'
        : 'Se conservará tu presupuesto original. El proveedor podrá aceptarlo o proponer otro precio.',
    boton: aceptar ? 'Aceptar precio' : 'Rechazar precio',
    accion: () => _repo.responderContraoferta(
      s.id,
      aceptar: aceptar,
      version: s.versionContraoferta,
    ),
    exito: aceptar
        ? 'Precio aceptado. Esperando confirmación del proveedor.'
        : 'Contraoferta rechazada.',
  );

  /// Rechaza la solicitud con un motivo obligatorio (mínimo 5 caracteres).
  Future<void> _rechazar(Solicitud s) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoRechazar(),
    );
    if (motivo == null) return;
    _hacer(s, () => _repo.rechazar(s.id, motivo), 'Solicitud rechazada');
  }

  /// Diálogo de confirmación reutilizable para completar o cancelar.
  Future<void> _confirmar(
    Solicitud s, {
    required String titulo,
    required String texto,
    required String boton,
    required Future<void> Function() accion,
    required String exito,
    bool peligro = false,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.of(context).card,
        title: Text(titulo, style: AppText.serif(22)),
        content: Text(
          texto,
          style: AppText.poppins(
            14,
            color: AppColors.of(context).texto2,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: peligro
                ? TextButton.styleFrom(
                    foregroundColor: AppColors.of(context).errorTexto,
                  )
                : null,
            child: Text(boton),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _hacer(s, accion, exito);
  }

  void _verServicio(Solicitud s) =>
      Navigator.of(context).pushNamed('/servicio', arguments: s.idServicio);

  @override
  Widget build(BuildContext context) {
    final pendientes =
        _recibidas?.where((s) => s.estado == 'Pendiente').length ?? 0;
    return DefaultTabController(
      length: 2,
      initialIndex: widget.pestanaInicial,
      child: Scaffold(
        backgroundColor: AppColors.of(context).bg,
        appBar: AppBar(
          backgroundColor: AppColors.of(context).bg,
          surfaceTintColor: Colors.transparent,
          title: Text('Mis solicitudes', style: AppText.serif(22)),
          bottom: TabBar(
            indicatorColor: AppColors.of(context).teal,
            labelColor: AppColors.of(context).teal,
            unselectedLabelColor: AppColors.of(context).texto2,
            dividerColor: AppColors.of(context).borde,
            labelStyle: AppText.poppins(14.5, weight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Flexible(
                      child: Text('Recibidas', overflow: TextOverflow.ellipsis),
                    ),
                    if (pendientes > 0) ...[
                      const SizedBox(width: 6),
                      Badge(
                        label: Text('$pendientes'),
                        backgroundColor: AppColors.of(context).amarillo,
                        textColor: AppColors.of(context).bg,
                      ),
                    ],
                  ],
                ),
              ),
              const Tab(text: 'Enviadas'),
            ],
          ),
        ),
        body: TabBarView(
          children: [_bandeja(recibidas: true), _bandeja(recibidas: false)],
        ),
      ),
    );
  }

  Widget _bandeja({required bool recibidas}) {
    final filtro = recibidas ? _filtroRecibidas : _filtroEnviadas;
    const opciones = <String?, String>{
      null: 'Todas',
      'Pendiente': 'Pendientes',
      'Aceptada': 'Aceptadas',
      'Completada': 'Completadas',
      'Rechazada': 'Rechazadas',
      'Cancelada': 'Canceladas',
    };
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              for (final opcion in opciones.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(opcion.value),
                    selected: filtro == opcion.key,
                    onSelected: (_) {
                      if (filtro == opcion.key) return;
                      setState(() {
                        if (recibidas) {
                          _filtroRecibidas = opcion.key;
                          _recibidas = null;
                          _errorRecibidas = null;
                        } else {
                          _filtroEnviadas = opcion.key;
                          _enviadas = null;
                          _errorEnviadas = null;
                        }
                      });
                      if (recibidas) {
                        _cargarRecibidas();
                      } else {
                        _cargarEnviadas();
                      }
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _Lista(
            solicitudes: recibidas ? _recibidas : _enviadas,
            error: recibidas ? _errorRecibidas : _errorEnviadas,
            onRecargar: recibidas ? _cargarRecibidas : _cargarEnviadas,
            vacioTitulo: filtro != null
                ? 'No hay solicitudes ${opciones[filtro]!.toLowerCase()}'
                : recibidas
                ? 'Aún no recibes solicitudes'
                : 'Aún no envías solicitudes',
            vacioTexto: filtro != null
                ? 'Selecciona otro estado o Todas para ver más solicitudes.'
                : recibidas
                ? 'Cuando alguien solicite uno de tus servicios aparecerá aquí.'
                : 'Busca un servicio en el inicio y toca "Enviar solicitud".',
            tarjeta: _tarjeta,
          ),
        ),
      ],
    );
  }

  /// Acciones visibles según los permisos que calcula cada [Solicitud].
  Widget _tarjeta(Solicitud s) {
    final acciones = <Widget>[
      OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pushNamed(
          '/chat',
          arguments: DestinoChat(
            contacto: ContactoChat(
              id: s.contraparte.id,
              nombre: s.contraparte.nombre,
              avatar: s.contraparte.avatar,
            ),
          ),
        ),
        style: _estiloSecundario(),
        icon: const Icon(Icons.chat_bubble_outline, size: 18),
        label: const Text('Chatear'),
      ),
      if (s.puedeRechazar)
        OutlinedButton(
          onPressed: () => _rechazar(s),
          style: _estiloSecundario(),
          child: const Text('Rechazar'),
        ),
      if (s.puedeAceptar)
        FilledButton(
          onPressed: () => _aceptar(s),
          style: _estiloPrincipal(),
          child: const Text('Aceptar'),
        ),
      if (s.puedeCompletar)
        FilledButton(
          onPressed: () => _confirmar(
            s,
            titulo: '¿Marcar como completada?',
            texto:
                'Hazlo cuando hayas terminado el servicio. ${s.cliente.nombre} podrá dejarte una reseña.',
            boton: 'Completada',
            accion: () => _repo.completar(s.id),
            exito: 'Solicitud completada',
          ),
          style: _estiloPrincipal(),
          child: const Text('Marcar como completada'),
        ),
      if (s.puedeContraofertar)
        OutlinedButton(
          onPressed: () => _contraofertar(s),
          style: _estiloSecundario(),
          child: const Text('Contraoferta'),
        ),
      if (s.puedeResponderContraoferta) ...[
        OutlinedButton(
          onPressed: () => _responderContraoferta(s, false),
          style: _estiloSecundario(),
          child: const Text('Rechazar contraoferta'),
        ),
        FilledButton(
          onPressed: () => _responderContraoferta(s, true),
          style: _estiloPrincipal(),
          child: const Text('Aceptar contraoferta'),
        ),
      ],
      if (s.puedeCancelar)
        OutlinedButton(
          onPressed: () => _confirmar(
            s,
            titulo: '¿Cancelar la solicitud?',
            texto: 'Avisaremos a ${s.proveedor.nombre}.',
            boton: 'Cancelar solicitud',
            accion: () => _repo.cancelar(s.id),
            exito: 'Solicitud cancelada',
            peligro: true,
          ),
          style: _estiloSecundario(),
          child: const Text('Cancelar solicitud'),
        ),
      if (s.puedeCalificar)
        FilledButton.icon(
          onPressed: () => _verServicio(s),
          style: _estiloPrincipal(),
          icon: const Icon(Icons.star_rounded, size: 18),
          label: const Text('Calificar'),
        ),
    ];
    return _TarjetaSolicitud(
      solicitud: s,
      ocupada: _ocupadas.contains(s.id),
      acciones: acciones,
      onTap: () => _verServicio(s),
    );
  }

  ButtonStyle _estiloPrincipal() => FilledButton.styleFrom(
    backgroundColor: AppColors.of(context).teal,
    foregroundColor: AppColors.of(context).bg,
    minimumSize: const Size(48, 44),
    textStyle: AppText.poppins(14, weight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  ButtonStyle _estiloSecundario() => OutlinedButton.styleFrom(
    foregroundColor: AppColors.of(context).texto,
    side: BorderSide(color: AppColors.of(context).bordeCampo),
    minimumSize: const Size(48, 44),
    textStyle: AppText.poppins(14, weight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

/// Lista de una bandeja con sus estados de carga, error y vacío.
class _Lista extends StatelessWidget {
  final List<Solicitud>? solicitudes;
  final String? error;
  final Future<void> Function() onRecargar;
  final String vacioTitulo;
  final String vacioTexto;
  final Widget Function(Solicitud) tarjeta;
  const _Lista({
    required this.solicitudes,
    required this.error,
    required this.onRecargar,
    required this.vacioTitulo,
    required this.vacioTexto,
    required this.tarjeta,
  });

  @override
  Widget build(BuildContext context) {
    final lista = solicitudes;
    Widget contenido;
    if (lista == null && error == null) {
      return Center(
        child: CircularProgressIndicator(color: AppColors.of(context).teal),
      );
    } else if (error != null || lista == null) {
      contenido = Column(
        children: [
          _Aviso(
            icono: Icons.cloud_off_rounded,
            titulo: 'No pudimos cargar las solicitudes',
            texto: error!,
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onRecargar, child: const Text('Reintentar')),
        ],
      );
    } else if (lista.isEmpty) {
      contenido = _Aviso(
        icono: Icons.inbox_outlined,
        titulo: vacioTitulo,
        texto: vacioTexto,
      );
    } else {
      return RefreshIndicator(
        color: AppColors.of(context).teal,
        backgroundColor: AppColors.of(context).card,
        onRefresh: onRecargar,
        child: ListView.separated(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          itemCount: lista.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (_, i) => Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: tarjeta(lista[i]),
            ),
          ),
        ),
      );
    }
    return RefreshIndicator(
      color: AppColors.of(context).teal,
      backgroundColor: AppColors.of(context).card,
      onRefresh: onRecargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [contenido],
      ),
    );
  }
}

/// Mensaje centrado para listas vacías o errores de carga.
class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Aviso({
    required this.icono,
    required this.titulo,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icono, size: 48, color: AppColors.of(context).texto2),
        const SizedBox(height: 16),
        Text(titulo, textAlign: TextAlign.center, style: AppText.serif(24)),
        const SizedBox(height: 8),
        Text(
          texto,
          textAlign: TextAlign.center,
          style: AppText.poppins(
            14,
            color: AppColors.of(context).texto2,
            height: 1.5,
          ),
        ),
      ],
    );
  }
}

/// Estado de una solicitud -> color; los estados desconocidos usan gris.
Color colorEstadoSolicitud(BuildContext context, String estado) =>
    switch (estado) {
      'Pendiente' => AppColors.of(context).amarillo,
      'Aceptada' => AppColors.of(context).teal2,
      'Completada' => AppColors.of(context).legible(const Color(0xFF34D399)),
      'Rechazada' => AppColors.of(context).errorTexto,
      _ => AppColors.of(context).legible(const Color(0xFF94A3B8)), // Cancelada
    };

// Nombres legibles de los campos extra que devuelve la API.
const _nombresCampos = {
  'cantidad_paginas': 'Páginas',
  'lenguaje': 'Lenguaje',
  'dias_estadia': 'Estadía',
  'fecha_inicio': 'Inicio',
};

/// Tarjeta de una solicitud: servicio, contraparte, estado, datos y acciones.
class _TarjetaSolicitud extends StatelessWidget {
  final Solicitud solicitud;
  final bool ocupada;
  final List<Widget> acciones;
  final VoidCallback onTap;
  const _TarjetaSolicitud({
    required this.solicitud,
    required this.ocupada,
    required this.acciones,
    required this.onTap,
  });

  String _fecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final s = solicitud;
    final color = colorEstadoSolicitud(context, s.estado);
    final datos = <(String, String)>[
      if (s.presupuesto != null)
        ('Presupuesto', formatearPrecio(s.presupuesto!)),
      if (s.contraoferta != null)
        (
          'Contraoferta (${s.estadoContraoferta ?? 'aceptada'})',
          formatearPrecio(s.contraoferta!),
        ),
      if ((s.estado == 'Aceptada' || s.estado == 'Completada') &&
          s.precioAcordado != null)
        ('Precio acordado', formatearPrecio(s.precioAcordado!)),
      if (s.fechaDeseada != null)
        (
          'Fecha',
          '${_fecha(s.fechaDeseada!)}${s.horaDeseada != null ? ' · ${s.horaDeseada}' : ''}',
        ),
      for (final e in s.campos.entries)
        if (e.key != 'fecha_inicio' || s.fechaDeseada == null)
          (
            _nombresCampos[e.key] ?? e.key,
            e.key == 'fecha_inicio'
                ? (DateTime.tryParse(e.value) != null
                      ? _fecha(DateTime.parse(e.value))
                      : e.value)
                : e.value,
          ),
    ];

    return Material(
      color: AppColors.of(context).card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: s.activa
                  ? AppColors.a(color, 0.35)
                  : AppColors.of(context).borde,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Miniatura(url: s.imagenServicio, categoria: s.categoria),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          s.tituloServicio,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            15,
                            weight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          s.soyCliente
                              ? 'Para ${s.proveedor.nombre}'
                              : 'De ${s.cliente.nombre}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.poppins(
                            13,
                            color: AppColors.of(context).texto2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.a(color, 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      s.estado,
                      style: AppText.poppins(
                        11.5,
                        weight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ),
                ],
              ),
              if (s.descripcion.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  s.descripcion,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    13.5,
                    color: AppColors.of(context).texto,
                    height: 1.45,
                  ),
                ),
              ],
              if (datos.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 16,
                  runSpacing: 6,
                  children: [
                    for (final (k, v) in datos)
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '$k: ',
                              style: AppText.poppins(
                                12.5,
                                color: AppColors.of(context).texto2,
                              ),
                            ),
                            TextSpan(
                              text: v,
                              style: AppText.poppins(
                                12.5,
                                weight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              if (s.estado == 'Rechazada' &&
                  (s.motivoRechazo?.isNotEmpty ?? false)) ...[
                const SizedBox(height: 10),
                Text(
                  'Motivo: ${s.motivoRechazo}',
                  style: AppText.poppins(
                    12.5,
                    color: AppColors.of(context).texto2,
                    height: 1.4,
                  ),
                ),
              ],
              if (s.avisoContraoferta != null) ...[
                const SizedBox(height: 12),
                Text(
                  s.avisoContraoferta!,
                  style: AppText.poppins(
                    13,
                    color: AppColors.of(context).teal2,
                    height: 1.4,
                  ),
                ),
              ],
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                ocupada
                    ? Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.of(context).teal,
                            ),
                          ),
                        ),
                      )
                    : Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 8,
                        runSpacing: 8,
                        children: acciones,
                      ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Foto del servicio o, si no hay, el icono y color de su categoría.
class _Miniatura extends StatelessWidget {
  final String? url;
  final String categoria;
  const _Miniatura({required this.url, required this.categoria});

  @override
  Widget build(BuildContext context) {
    const lado = 52.0;
    final color = AppColors.of(
      context,
    ).legible(coloresCategoria[categoria]?.color ?? AppColors.of(context).teal);
    final respaldo = ColoredBox(
      color: AppColors.a(color, 0.15),
      child: Icon(
        iconosPorCategoria[categoria] ?? iconoPorDefecto,
        color: color,
        size: 24,
      ),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
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

/// Proponer un precio no acepta el servicio; primero debe responder el cliente.
class _DialogoContraoferta extends StatefulWidget {
  final Solicitud solicitud;
  const _DialogoContraoferta({required this.solicitud});

  @override
  State<_DialogoContraoferta> createState() => _DialogoContraofertaState();
}

class _DialogoContraofertaState extends State<_DialogoContraoferta> {
  final _contraoferta = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _contraoferta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    return AlertDialog(
      backgroundColor: AppColors.of(context).card,
      title: Text('Enviar contraoferta', style: AppText.serif(22)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.presupuesto != null
                ? '${s.cliente.nombre} ofrece ${formatearPrecio(s.presupuesto!)}. Propón otro precio; cuando lo acepte podrás confirmar el servicio.'
                : 'Propón un precio; cuando el cliente lo acepte podrás confirmar el servicio.',
            style: AppText.poppins(
              14,
              color: AppColors.of(context).texto2,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contraoferta,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: InputDecoration(
              labelText: 'Precio de la contraoferta',
              errorText: _error,
              prefixText: '\$ ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        TextButton(
          onPressed: () {
            final n = int.tryParse(_contraoferta.text);
            if (n == null || n < 1 || n > 99999999) {
              setState(() => _error = 'Ingresa un precio entre 1 y 99.999.999');
              return;
            }
            Navigator.of(context).pop(n);
          },
          child: const Text('Enviar contraoferta'),
        ),
      ],
    );
  }
}

/// Diálogo para rechazar; valida el motivo y lo devuelve como String.
class _DialogoRechazar extends StatefulWidget {
  const _DialogoRechazar();

  @override
  State<_DialogoRechazar> createState() => _DialogoRechazarState();
}

class _DialogoRechazarState extends State<_DialogoRechazar> {
  final _motivo = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _motivo.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.of(context).card,
      title: Text('Rechazar solicitud', style: AppText.serif(22)),
      content: TextField(
        controller: _motivo,
        autofocus: true,
        minLines: 2,
        maxLines: 4,
        maxLength: 1000,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Motivo',
          hintText: 'Ej: No tengo disponibilidad esa semana',
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Volver'),
        ),
        TextButton(
          onPressed: () {
            final t = _motivo.text.trim();
            if (t.length < 5) {
              setState(
                () => _error = 'Explica el motivo (mínimo 5 caracteres)',
              );
              return;
            }
            Navigator.of(context).pop(t);
          },
          style: TextButton.styleFrom(
            foregroundColor: AppColors.of(context).errorTexto,
          ),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
