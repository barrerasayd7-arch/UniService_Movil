import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/solicitud_config.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'detail_widgets.dart';

/// `.form-solicitud` (FormularioSolicitud.jsx). Los campos dependen de la
/// categoría del servicio (tutorías, ensayos, arriendo...).
class FormSolicitud extends StatefulWidget {
  final String categoria;
  final String proveedorNombre;
  const FormSolicitud({
    super.key,
    required this.categoria,
    required this.proveedorNombre,
  });

  @override
  State<FormSolicitud> createState() => _FormSolicitudState();
}

class _FormSolicitudState extends State<FormSolicitud> {
  late final ConfigSolicitud _config = configSolicitud(widget.categoria);
  final Map<String, TextEditingController> _ctrl = {};
  final Map<String, DateTime> _fechas = {};
  final Map<String, TimeOfDay> _horas = {};
  final Map<String, String> _selects = {};

  bool _solicitudExiste = false; 
  bool _enviando = false;

  @override
  void initState() {
    super.initState();
    for (final c in _config.campos) {
      if (c.tipo == TipoCampo.textarea || c.tipo == TipoCampo.number) {
        _ctrl[c.nombre] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrl.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Helpers ──
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
    final hoy = DateTime.now();
    // En "fecha de inicio" no se permiten fechas pasadas (como en la web)
    final primera = c.nombre.contains('inicio') ? DateTime(hoy.year, hoy.month, hoy.day) : DateTime(2020);
    final d = await showDatePicker(
      context: context,
      initialDate: _fechas[c.nombre] ?? (primera.isAfter(hoy) ? primera : hoy),
      firstDate: primera,
      lastDate: DateTime(hoy.year + 5),
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

  bool _validar() {
    for (final c in _config.campos) {
      if (c.obligatorio && !_lleno(c)) {
        mostrarNotificacion(context, "El campo '${c.label}' es obligatorio");
        return false;
      }
    }
    final p = int.tryParse(_ctrl['presupuesto']?.text ?? '');
    if (p != null && p > 9999999) {
      mostrarNotificacion(context, 'El presupuesto es demasiado grande');
      return false;
    }
    return true;
  }

  void _limpiar() {
    for (final c in _ctrl.values) {
      c.clear();
    }
    _fechas.clear();
    _horas.clear();
    _selects.clear();
  }

  Future<void> _accion() async {
    if (_solicitudExiste) {
      
      setState(() => _solicitudExiste = false);
      mostrarNotificacion(context, 'Solicitud eliminada', exito: true);
      return;
    }
    if (!_validar()) return;
    setState(() => _enviando = true);
    
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _solicitudExiste = true;
      _limpiar();
    });
    mostrarNotificacion(context, 'Solicitud enviada', exito: true);
  }

  // ── Construcción ──
  @override
  Widget build(BuildContext context) {
    final movil = MediaQuery.of(context).size.width <= 540;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: movil ? 20 : 28, horizontal: movil ? 16 : 24),
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
              border: Border(bottom: BorderSide(color: AppColors.teal, width: 2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.edit_note, size: 20, color: AppColors.texto),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${_config.titulo} a ${widget.proveedorNombre}',
                    style: AppText.poppins(16, weight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          for (final c in _config.campos) _campo(c),
          BtnDetalle(
            label: _enviando
                ? 'Enviando...'
                : _solicitudExiste
                    ? 'Eliminar solicitud'
                    : 'Enviar solicitud',
            icono: _solicitudExiste ? Icons.delete_outline : Icons.mail_outline,
            cargando: _enviando,
            onTap: _accion,
          ),
          if (_solicitudExiste)
            Padding(
              padding: const EdgeInsets.only(top: 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.info_outline, size: 14, color: AppColors.texto2),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'Ya tienes una solicitud activa para este servicio.',
                      textAlign: TextAlign.center,
                      style: AppText.poppins(13.1, color: AppColors.texto2),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// `.form-grupo-custom`: etiqueta con icono + control.
  Widget _campo(CampoSolicitud c) {
    final lleno = _lleno(c);

    IconData icono;
    switch (c.tipo) {
      case TipoCampo.textarea:
        icono = Icons.edit_note;
      case TipoCampo.date:
        icono = Icons.calendar_today_outlined;
      case TipoCampo.time:
        icono = Icons.access_time;
      case TipoCampo.number:
        icono = Icons.payments_outlined;
      case TipoCampo.select:
        icono = Icons.list;
      case TipoCampo.file:
        icono = Icons.attach_file;
    }

    // Los campos de archivo traen la etiqueta dentro del propio botón
    if (c.tipo == TipoCampo.file) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 18),
        child: _BotonArchivo(
          label: c.label,
          onTap: () {
            
            mostrarNotificacion(context, 'Aquí se abriría el selector de archivos (file_picker).');
          },
        ),
      );
    }

    final obligatorioMarca = c.obligatorio ||
        c.tipo == TipoCampo.time ||
        c.tipo == TipoCampo.number; // la web marca * en hora y presupuesto

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 15, color: lleno ? AppColors.teal : AppColors.texto2),
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
                  child: Text('*', style: AppText.poppins(13.6, color: AppColors.teal)),
                ),
            ],
          ),
          const SizedBox(height: 7),
          _control(c, lleno),
        ],
      ),
    );
  }

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
              LengthLimitingTextInputFormatter(10),
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
            _fechas[c.nombre] != null ? _fmtFecha(_fechas[c.nombre]!) : 'Selecciona una fecha',
            _fechas[c.nombre] != null,
            Icons.calendar_today_outlined,
          ),
        );
      case TipoCampo.time:
        return CampoCaja(
          lleno: lleno,
          onTap: () => _elegirHora(c),
          child: _valorFalso(
            _horas[c.nombre] != null ? _horas[c.nombre]!.format(context) : '--:-- --',
            _horas[c.nombre] != null,
            Icons.access_time,
          ),
        );
      case TipoCampo.select:
        return CampoCaja(
          lleno: lleno,
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: (_selects[c.nombre] ?? '').isEmpty ? null : _selects[c.nombre],
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
                for (final o in c.opciones) DropdownMenuItem(value: o, child: Text(o)),
              ],
              onChanged: (v) => setState(() => _selects[c.nombre] = v ?? ''),
            ),
          ),
        );
      case TipoCampo.file:
        return const SizedBox.shrink();
    }
  }

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

/// `.custom-file-upload`: botón con borde discontinuo.
class _BotonArchivo extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _BotonArchivo({required this.label, required this.onTap});

  @override
  State<_BotonArchivo> createState() => _BotonArchivoState();
}

class _BotonArchivoState extends State<_BotonArchivo> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final color = _hover ? AppColors.teal : AppColors.texto2;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: CustomPaint(
          foregroundPainter: _BordeDiscontinuo(_hover ? AppColors.teal : AppColors.borde2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _hover ? AppColors.a(AppColors.teal, 0.08) : AppColors.bg2,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.attach_file, size: 16, color: color),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    widget.label,
                    textAlign: TextAlign.center,
                    style: AppText.poppins(14.08, weight: FontWeight.w600, color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BordeDiscontinuo extends CustomPainter {
  final Color color;
  _BordeDiscontinuo(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(12),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 6), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _BordeDiscontinuo old) => old.color != color;
}
