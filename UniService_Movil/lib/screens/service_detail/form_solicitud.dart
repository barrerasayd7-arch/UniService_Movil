// Archivo: form_solicitud.dart
// Responsabilidad: solicitud de un servicio con campos según categoría y estado activo.
// Se usa desde: detail_screen (columna derecha) y reutiliza CampoCaja en reseñas.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearPrecio;
import '../../core/solicitud_config.dart';
import '../../data/api_client.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'detail_widgets.dart';

/// Formulario para solicitar el servicio (`POST /api/solicitudes`). Los campos
/// dependen de la categoría (tutorías, ensayos, arriendo...).
///
/// Si el usuario ya tiene una solicitud activa para este servicio, muestra su
/// estado y permite cancelarla en lugar del formulario.
class FormSolicitud extends StatefulWidget {
  final int idServicio;
  final String categoria;
  final String proveedorNombre;
  final VoidCallback onVerSolicitudes;
  final SolicitudesRepository? repositorio;
  const FormSolicitud({
    super.key,
    required this.idServicio,
    required this.categoria,
    required this.proveedorNombre,
    required this.onVerSolicitudes,
    this.repositorio,
  });

  @override
  State<FormSolicitud> createState() => _FormSolicitudState();
}

class _FormSolicitudState extends State<FormSolicitud> {
  late final SolicitudesRepository _repo =
      widget.repositorio ?? SolicitudesRepository.instance;
  late final ConfigSolicitud _config = configSolicitud(widget.categoria);
  // Adjuntar archivos aún no está disponible en la API (necesita un bucket privado).
  late final List<CampoSolicitud> _campos = _config.campos
      .where((c) => c.tipo != TipoCampo.file)
      .toList();
  // Un control por campo dinámico, indexado por su nombre en la configuración.
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, DateTime> _fechas = {};
  final Map<String, TimeOfDay> _horas = {};
  final Map<String, String> _selects = {};

  Solicitud? _activa;
  bool _consultando = true;
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    for (final c in _campos) {
      if (c.tipo == TipoCampo.textarea || c.tipo == TipoCampo.number) {
        _ctrl[c.nombre] = TextEditingController();
      }
    }
    _consultarActiva();
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Busca una solicitud activa del usuario para este servicio; si existe, el
  /// formulario se sustituye por su estado y la opción de cancelarla.
  Future<void> _consultarActiva() async {
    setState(() => _consultando = true);
    Solicitud? activa;
    try {
      activa = await _repo.activaPara(widget.idServicio);
    } on ApiException {
      // Sin la consulta se muestra el formulario; si ya existe, la API responde 409.
    }
    if (mounted) {
      setState(() {
        _activa = activa;
        _consultando = false;
      });
    }
  }

  // --- Helpers de campos dinámicos ---

  /// Indica si un campo tiene valor, para resaltar su etiqueta y borde.
  bool _lleno(CampoSolicitud c) {
    switch (c.tipo) {
      case TipoCampo.textarea:
      case TipoCampo.number:
        return (_ctrl[c.nombre]?.text ?? '').trim().isNotEmpty;
      case TipoCampo.date:
        return _fechas.containsKey(c.nombre);
      case TipoCampo.time:
        return _horas.containsKey(c.nombre);
      case TipoCampo.select:
        return (_selects[c.nombre] ?? '').isNotEmpty;
      case TipoCampo.file:
        return false;
    }
  }

  String _fmtFecha(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _elegirFecha(CampoSolicitud c) async {
    final ahora = DateTime.now();
    // La API no acepta fechas pasadas.
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final d = await showDatePicker(
      context: context,
      initialDate: _fechas[c.nombre] ?? hoy,
      firstDate: hoy,
      lastDate: DateTime(hoy.year + 2),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.teal,
            onPrimary: AppColors.bg,
            surface: AppColors.card,
            onSurface: AppColors.texto,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _fechas[c.nombre] = d);
  }

  Future<void> _elegirHora(CampoSolicitud c) async {
    final t = await showTimePicker(
      context: context,
      initialTime: _horas[c.nombre] ?? TimeOfDay.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.teal,
            onPrimary: AppColors.bg,
            surface: AppColors.card,
            onSurface: AppColors.texto,
          ),
        ),
        child: child!,
      ),
    );
    if (t != null) setState(() => _horas[c.nombre] = t);
  }

  /// Valida obligatorios, descripción mínima y rango del presupuesto.
  bool _validar() {
    for (final c in _campos) {
      if (c.obligatorio && !_lleno(c)) {
        mostrarNotificacion(context, "El campo '${c.label}' es obligatorio");
        return false;
      }
    }
    if ((_ctrl['descripcion']?.text.trim().length ?? 0) < 10) {
      mostrarNotificacion(
        context,
        'Describe lo que necesitas (mínimo 10 caracteres)',
      );
      return false;
    }
    final p = int.tryParse(_ctrl['presupuesto']?.text ?? '') ?? 0;
    if (p < 1) {
      mostrarNotificacion(context, 'Indica un presupuesto mayor a 0');
      return false;
    }
    if (p > 99999999) {
      mostrarNotificacion(context, 'El presupuesto es demasiado grande');
      return false;
    }
    return true;
  }

  /// Envía la solicitud (`POST /api/solicitudes`); un 409 significa que ya
  /// existía una activa, así que se vuelve a consultar el estado.
  Future<void> _enviar() async {
    if (!_validar()) return;
    setState(() => _enviando = true);
    final hora = _horas['hora_deseada'];
    final inicio = _fechas['fecha_inicio'];
    try {
      await _repo.crear(
        idServicio: widget.idServicio,
        descripcion: _ctrl['descripcion']!.text,
        presupuesto: int.parse(_ctrl['presupuesto']!.text),
        // En arriendo la fecha que importa es la de inicio.
        fechaDeseada: _fechas['fecha_deseada'] ?? inicio,
        horaDeseada: hora == null
            ? null
            : '${hora.hour.toString().padLeft(2, '0')}:${hora.minute.toString().padLeft(2, '0')}',
        campos: {
          for (final e in _selects.entries)
            if (e.value.isNotEmpty) e.key: e.value,
          if (inicio != null) 'fecha_inicio': fechaIso(inicio),
        },
      );
      if (!mounted) return;
      mostrarNotificacion(
        context,
        'Solicitud enviada. ${widget.proveedorNombre} recibirá un aviso y podrán hablar por el chat.',
        exito: true,
      );
      _consultarActiva();
    } on ApiException catch (e) {
      if (!mounted) return;
      mostrarNotificacion(context, e.mensaje);
      if (e.status == 409) _consultarActiva();
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Cancela la solicitud tras confirmar; limpia el formulario para permitir
  /// enviar otra.
  Future<void> _cancelar(Solicitud s) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text('¿Cancelar la solicitud?', style: AppText.serif(22)),
        content: Text(
          'Avisaremos a ${widget.proveedorNombre}. Si cambias de opinión, puedes enviar otra.',
          style: AppText.poppins(14, color: AppColors.texto2, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Volver'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.errorTexto),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() => _enviando = true);
    try {
      await _repo.cancelar(s.id);
      if (!mounted) return;
      _limpiar();
      mostrarNotificacion(context, 'Solicitud cancelada', exito: true);
      _consultarActiva();
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Vacía textos, fechas, horas y selects de todos los campos dinámicos.
  void _limpiar() {
    for (final c in _ctrl.values) {
      c.clear();
    }
    _fechas.clear();
    _horas.clear();
    _selects.clear();
  }

  // --- Construcción ---
  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= 540;
    final activa = _activa;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        vertical: movil ? 20 : 28,
        horizontal: movil ? 16 : 24,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borde),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.card,
            Color.alphaBlend(AppColors.a(AppColors.teal, 0.02), AppColors.card),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.only(bottom: 12),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: const BoxDecoration(
              border: Border(
                bottom: BorderSide(color: AppColors.teal, width: 2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20, color: AppColors.texto),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    activa != null
                        ? 'Tu solicitud a ${widget.proveedorNombre}'
                        : '${_config.titulo} a ${widget.proveedorNombre}',
                    style: AppText.poppins(16, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (_consultando)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: CircularProgressIndicator(color: AppColors.teal),
              ),
            )
          else if (activa != null)
            ..._solicitudActiva(activa)
          else ...[
            for (final c in _campos) _campo(c),
            BtnDetalle(
              label: _enviando ? 'Enviando...' : 'Enviar solicitud',
              icono: Icons.send_outlined,
              cargando: _enviando,
              margenInferior: false,
              onTap: _enviar,
            ),
          ],
        ],
      ),
    );
  }

  /// Estado de la solicitud ya enviada: aviso, acceso a la lista y cancelación.
  List<Widget> _solicitudActiva(Solicitud s) {
    final aceptada = s.estado == 'Aceptada';
    final color = aceptada ? const Color(0xFF34D399) : AppColors.amarillo;
    return [
      Container(
        padding: const EdgeInsets.all(14),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.a(color, 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.a(color, 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              aceptada ? Icons.check_circle_outline : Icons.schedule,
              color: color,
              size: 22,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    aceptada
                        ? '${widget.proveedorNombre} aceptó tu solicitud'
                        : 'Esperando respuesta de ${widget.proveedorNombre}',
                    style: AppText.poppins(14.5, weight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    [
                      if (s.presupuesto != null)
                        'Tu presupuesto: ${formatearPrecio(s.presupuesto!)}',
                      if (s.contraoferta != null)
                        'Contraoferta: ${formatearPrecio(s.contraoferta!)}',
                    ].join(' · '),
                    style: AppText.poppins(13, color: AppColors.texto2),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      BtnDetalle(
        label: 'Ver mis solicitudes',
        icono: Icons.list_alt,
        onTap: widget.onVerSolicitudes,
      ),
      BtnDetalle(
        label: _enviando ? 'Cancelando...' : 'Cancelar solicitud',
        icono: Icons.close,
        estilo: EstiloBtn.secundario,
        cargando: _enviando,
        margenInferior: false,
        onTap: () => _cancelar(s),
      ),
    ];
  }

  /// `.form-grupo-custom`: etiqueta con icono + control.
  Widget _campo(CampoSolicitud c) {
    final lleno = _lleno(c);

    final icono = switch (c.tipo) {
      TipoCampo.textarea => Icons.edit_note,
      TipoCampo.date => Icons.calendar_today_outlined,
      TipoCampo.time => Icons.access_time,
      TipoCampo.number => Icons.payments_outlined,
      TipoCampo.select => Icons.list,
      TipoCampo.file => Icons.attach_file,
    };

    final obligatorioMarca =
        c.obligatorio ||
        c.tipo == TipoCampo.time ||
        c.tipo == TipoCampo.number; // la web marca * en hora y presupuesto

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icono,
                size: 15,
                color: lleno ? AppColors.teal : AppColors.texto2,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  c.label,
                  style: AppText.poppins(
                    13.6,
                    weight: FontWeight.w600,
                    color: lleno ? AppColors.teal : AppColors.texto2,
                  ),
                ),
              ),
              if (obligatorioMarca)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    '*',
                    style: AppText.poppins(13.6, color: AppColors.teal),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 7),
          _control(c, lleno),
        ],
      ),
    );
  }

  /// Devuelve el control adecuado al tipo de campo; fechas y horas se eligen
  /// con selectores y los selects con un desplegable.
  Widget _control(CampoSolicitud c, bool lleno) {
    switch (c.tipo) {
      case TipoCampo.textarea:
        return CampoCaja(
          lleno: lleno,
          child: TextField(
            controller: _ctrl[c.nombre],
            onChanged: (_) => setState(() {}),
            minLines: 4,
            maxLines: 8,
            maxLength: 2000,
            buildCounter: _sinContador,
            cursorColor: AppColors.teal,
            style: AppText.poppins(14.08, height: 1.6),
            decoration: _deco(c.placeholder),
          ),
        );
      case TipoCampo.number:
        return CampoCaja(
          lleno: lleno,
          child: TextField(
            controller: _ctrl[c.nombre],
            onChanged: (_) => setState(() {}),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(8),
            ],
            cursorColor: AppColors.teal,
            style: AppText.poppins(14.08),
            decoration: _deco(c.placeholder),
          ),
        );
      case TipoCampo.date:
        return CampoCaja(
          lleno: lleno,
          onTap: () => _elegirFecha(c),
          child: _valorFalso(
            _fechas[c.nombre] != null
                ? _fmtFecha(_fechas[c.nombre]!)
                : 'Selecciona una fecha',
            _fechas[c.nombre] != null,
            Icons.calendar_today_outlined,
          ),
        );
      case TipoCampo.time:
        return CampoCaja(
          lleno: lleno,
          onTap: () => _elegirHora(c),
          child: _valorFalso(
            _horas[c.nombre] != null
                ? _horas[c.nombre]!.format(context)
                : '--:-- --',
            _horas[c.nombre] != null,
            Icons.access_time,
          ),
        );
      case TipoCampo.select:
        return CampoCaja(
          lleno: lleno,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (_selects[c.nombre] ?? '').isEmpty
                  ? null
                  : _selects[c.nombre],
              isExpanded: true,
              hint: Text(
                c.placeholder ?? 'Selecciona',
                style: AppText.poppins(14.08, color: AppColors.texto3),
              ),
              dropdownColor: AppColors.bg2,
              iconEnabledColor: AppColors.teal,
              icon: const Icon(Icons.arrow_drop_down),
              style: AppText.poppins(14.08),
              items: [
                for (final o in c.opciones)
                  DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => setState(() => _selects[c.nombre] = v ?? ''),
            ),
          ),
        );
      case TipoCampo.file:
        return const SizedBox.shrink();
    }
  }

  static Widget? _sinContador(
    BuildContext _, {
    required int currentLength,
    required bool isFocused,
    required int? maxLength,
  }) => null;

  InputDecoration _deco(String? hint) => InputDecoration(
    isDense: true,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    hintText: hint,
    hintStyle: AppText.poppins(14.08, color: AppColors.texto3),
    contentPadding: EdgeInsets.zero,
  );

  Widget _valorFalso(String texto, bool tieneValor, IconData icono) {
    return Row(
      children: [
        Expanded(
          child: Text(
            texto,
            style: AppText.poppins(
              14.08,
              color: tieneValor ? AppColors.texto : AppColors.texto3,
            ),
          ),
        ),
        Icon(icono, size: 17, color: const Color(0xFF3AB5B0)),
      ],
    );
  }
}

/// Caja de un campo (`.form-input-custom`): fondo, borde 2px y foco teal.
/// Mantiene sus propios estados de hover y foco; con [onTap] se comporta como
/// un campo de solo lectura que abre un selector.
class CampoCaja extends StatefulWidget {
  final Widget child;
  final bool lleno;
  final VoidCallback? onTap;
  const CampoCaja({super.key, required this.child, required this.lleno, this.onTap});

  @override
  State<CampoCaja> createState() => _CampoCajaState();
}

class _CampoCajaState extends State<CampoCaja> {
  bool _hover = false;
  bool _foco = false;

  @override
  Widget build(BuildContext context) {
    final borde = _foco
        ? AppColors.teal
        : widget.lleno
            ? AppColors.a(AppColors.teal, 0.4)
            : (_hover ? AppColors.borde2 : AppColors.borde);

    return MouseRegion(
      cursor: widget.onTap != null ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: Focus(
        onFocusChange: (f) => setState(() => _foco = f),
        child: GestureDetector(
          onTap: widget.onTap,
          behavior: HitTestBehavior.opaque,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _foco ? AppColors.bg3 : AppColors.bg2,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: borde, width: 2),
              boxShadow: _foco
                  ? [
                      BoxShadow(
                        color: AppColors.a(AppColors.teal, 0.12),
                        spreadRadius: 3,
                      ),
                    ]
                  : const [],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

