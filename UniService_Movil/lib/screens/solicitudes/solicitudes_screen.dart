import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart';
import '../../data/api_client.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;

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

class _SolicitudesScreenState extends State<SolicitudesScreen> {
  late final SolicitudesRepository _repo =
      widget.repositorio ?? SolicitudesRepository.instance;
  List<Solicitud>? _recibidas;
  List<Solicitud>? _enviadas;
  String? _errorRecibidas;
  String? _errorEnviadas;
  final Set<int> _ocupadas = {};

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

  Future<void> _cargar() => Future.wait([_cargarRecibidas(), _cargarEnviadas()]);

  Future<void> _cargarRecibidas() async {
    try {
      final l = await _repo.recibidas();
      if (mounted) {
        setState(() {
          _recibidas = l;
          _errorRecibidas = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorRecibidas = e.mensaje);
    }
  }

  Future<void> _cargarEnviadas() async {
    try {
      final l = await _repo.enviadas();
      if (mounted) {
        setState(() {
          _enviadas = l;
          _errorEnviadas = null;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorEnviadas = e.mensaje);
    }
  }

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

  Future<void> _aceptar(Solicitud s) async {
    final r = await showDialog<({int? contraoferta})>(
      context: context,
      builder: (_) => _DialogoAceptar(solicitud: s),
    );
    if (r == null) return;
    _hacer(
      s,
      () => _repo.aceptar(s.id, contraoferta: r.contraoferta),
      'Aceptaste la solicitud de ${s.cliente.nombre}. Coordinen los detalles por el chat.',
    );
  }

  Future<void> _rechazar(Solicitud s) async {
    final motivo = await showDialog<String>(
      context: context,
      builder: (_) => const _DialogoRechazar(),
    );
    if (motivo == null) return;
    _hacer(s, () => _repo.rechazar(s.id, motivo), 'Solicitud rechazada');
  }

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
        backgroundColor: AppColors.card,
        title: Text(titulo, style: AppText.serif(22)),
        content: Text(
          texto,
          style: AppText.poppins(14, color: AppColors.texto2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: peligro
                ? TextButton.styleFrom(foregroundColor: AppColors.errorTexto)
                : null,
            child: Text(boton),
          ),
        ],
      ),
    );
    if (ok == true) _hacer(s, accion, exito);
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
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          backgroundColor: AppColors.bg,
          surfaceTintColor: Colors.transparent,
          title: Text('Mis solicitudes', style: AppText.serif(22)),
          bottom: TabBar(
            indicatorColor: AppColors.teal,
            labelColor: AppColors.teal,
            unselectedLabelColor: AppColors.texto2,
            dividerColor: AppColors.borde,
            labelStyle: AppText.poppins(14.5, weight: FontWeight.w600),
            tabs: [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Recibidas'),
                    if (pendientes > 0) ...[
                      const SizedBox(width: 6),
                      Badge(
                        label: Text('$pendientes'),
                        backgroundColor: AppColors.amarillo,
                        textColor: AppColors.bg,
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
          children: [
            _Lista(
              solicitudes: _recibidas,
              error: _errorRecibidas,
              onRecargar: _cargarRecibidas,
              vacioTitulo: 'Aún no recibes solicitudes',
              vacioTexto:
                  'Cuando alguien solicite uno de tus servicios aparecerá aquí.',
              tarjeta: _tarjeta,
            ),
            _Lista(
              solicitudes: _enviadas,
              error: _errorEnviadas,
              onRecargar: _cargarEnviadas,
              vacioTitulo: 'Aún no envías solicitudes',
              vacioTexto:
                  'Busca un servicio en el inicio y toca "Enviar solicitud".',
              tarjeta: _tarjeta,
            ),
          ],
        ),
      ),
    );
  }

  Widget _tarjeta(Solicitud s) {
    final acciones = <Widget>[
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
    backgroundColor: AppColors.teal,
    foregroundColor: AppColors.bg,
    minimumSize: const Size(48, 44),
    textStyle: AppText.poppins(14, weight: FontWeight.w700),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );

  ButtonStyle _estiloSecundario() => OutlinedButton.styleFrom(
    foregroundColor: AppColors.texto,
    side: const BorderSide(color: AppColors.bordeCampo),
    minimumSize: const Size(48, 44),
    textStyle: AppText.poppins(14, weight: FontWeight.w600),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  );
}

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
      return const Center(
        child: CircularProgressIndicator(color: AppColors.teal),
      );
    } else if (lista == null) {
      contenido = _Aviso(
        icono: Icons.cloud_off_rounded,
        titulo: 'No pudimos cargar las solicitudes',
        texto: error!,
      );
    } else if (lista.isEmpty) {
      contenido = _Aviso(
        icono: Icons.inbox_outlined,
        titulo: vacioTitulo,
        texto: vacioTexto,
      );
    } else {
      return RefreshIndicator(
        color: AppColors.teal,
        backgroundColor: AppColors.card,
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
      color: AppColors.teal,
      backgroundColor: AppColors.card,
      onRefresh: onRecargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(24, 80, 24, 24),
        children: [contenido],
      ),
    );
  }
}

class _Aviso extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String texto;
  const _Aviso({required this.icono, required this.titulo, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Column(
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
      ],
    );
  }
}

/// Estado de una solicitud -> color.
Color colorEstadoSolicitud(String estado) => switch (estado) {
  'Pendiente' => AppColors.amarillo,
  'Aceptada' => AppColors.teal2,
  'Completada' => const Color(0xFF34D399),
  'Rechazada' => AppColors.errorTexto,
  _ => const Color(0xFF94A3B8), // Cancelada
};

const _nombresCampos = {
  'cantidad_paginas': 'Páginas',
  'lenguaje': 'Lenguaje',
  'dias_estadia': 'Estadía',
  'fecha_inicio': 'Inicio',
};

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
    final color = colorEstadoSolicitud(s.estado);
    final datos = <(String, String)>[
      if (s.presupuesto != null) ('Presupuesto', formatearPrecio(s.presupuesto!)),
      if (s.contraoferta != null)
        ('Contraoferta', formatearPrecio(s.contraoferta!)),
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
      color: AppColors.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: s.activa ? AppColors.a(color, 0.35) : AppColors.borde,
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
                          style: AppText.poppins(13, color: AppColors.texto2),
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
                    color: AppColors.texto,
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
                                color: AppColors.texto2,
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
                    color: AppColors.texto2,
                    height: 1.4,
                  ),
                ),
              ],
              if (acciones.isNotEmpty) ...[
                const SizedBox(height: 12),
                ocupada
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(10),
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.teal,
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

class _Miniatura extends StatelessWidget {
  final String? url;
  final String categoria;
  const _Miniatura({required this.url, required this.categoria});

  @override
  Widget build(BuildContext context) {
    const lado = 52.0;
    final color = coloresCategoria[categoria]?.color ?? AppColors.teal;
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

class _DialogoAceptar extends StatefulWidget {
  final Solicitud solicitud;
  const _DialogoAceptar({required this.solicitud});

  @override
  State<_DialogoAceptar> createState() => _DialogoAceptarState();
}

class _DialogoAceptarState extends State<_DialogoAceptar> {
  final _contraoferta = TextEditingController();

  @override
  void dispose() {
    _contraoferta.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.solicitud;
    return AlertDialog(
      backgroundColor: AppColors.card,
      title: Text('Aceptar solicitud', style: AppText.serif(22)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            s.presupuesto != null
                ? '${s.cliente.nombre} ofrece ${formatearPrecio(s.presupuesto!)}. Si quieres otro precio, escribe una contraoferta.'
                : 'Si quieres proponer un precio, escribe una contraoferta.',
            style: AppText.poppins(14, color: AppColors.texto2, height: 1.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contraoferta,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            decoration: const InputDecoration(
              labelText: 'Contraoferta (opcional)',
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
            Navigator.of(
              context,
            ).pop((contraoferta: n != null && n > 0 ? n : null));
          },
          child: const Text('Aceptar'),
        ),
      ],
    );
  }
}

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
      backgroundColor: AppColors.card,
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
              setState(() => _error = 'Explica el motivo (mínimo 5 caracteres)');
              return;
            }
            Navigator.of(context).pop(t);
          },
          style: TextButton.styleFrom(foregroundColor: AppColors.errorTexto),
          child: const Text('Rechazar'),
        ),
      ],
    );
  }
}
