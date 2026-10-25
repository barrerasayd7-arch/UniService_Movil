// Archivo: admin_reportes_screen.dart
// Responsabilidad: bandeja de reportes de usuarios con filtro por estado y una hoja para
//   cambiar el estado, dejar notas y revisar evidencias.
// Se usa desde: la sección "Reportes" del panel (ruta '/admin/reportes').

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/admin_repository.dart';
import '../../data/api_client.dart';
import '../../models/admin_models.dart';
import '../login/auth_widgets.dart';
import 'admin_comun.dart';
import 'admin_widgets.dart';

// Estados posibles y su color; los valores deben coincidir con los de la API.
const _estados = [
  'Pendiente',
  'En_revision',
  'Resuelto',
  'Rechazado',
  'Cerrado',
];

// Nombres legibles de los tipos de reporte; un tipo nuevo se muestra tal cual.
const _tipos = {
  'servicio_fraude': 'Fraude en servicio',
  'servicio_inapropiado': 'Servicio inapropiado',
  'usuario_acoso': 'Acoso de usuario',
  'usuario_abuso': 'Abuso de plataforma',
  'usuario_fraude': 'Fraude de usuario',
  'usuario_suplantacion': 'Suplantación de identidad',
  'usuario_spam': 'Spam / Publicidad',
  'usuario_comportamiento': 'Comportamiento inapropiado',
  'bug_tecnico': 'Error técnico',
  'queja_general': 'Queja general',
  'sugerencia': 'Sugerencia',
  'contenido_inapropiado': 'Contenido inapropiado',
  'pago_problema': 'Problema de pago',
  'otro': 'Otro',
};

String _etiquetaTipo(String t) => _tipos[t] ?? t;
String _etiquetaEstado(String e) => e.replaceAll('_', ' ');

Color _colorEstado(String e) => switch (e) {
  'Pendiente' => const Color(0xFFF59E0B),
  'En_revision' => const Color(0xFF60A5FA),
  'Resuelto' => const Color(0xFF34D399),
  'Rechazado' => const Color(0xFFF87171),
  _ => const Color(0xFF9CA3AF),
};

// Las evidencias pueden ser imágenes o enlaces; solo las imágenes se abren con zoom.
final _esImagen = RegExp(r'\.(jpg|jpeg|png|webp)(\?|$)', caseSensitive: false);

/// Reportes de usuarios: filtro por estado y gestión (estado + notas) en una hoja.
class AdminReportesScreen extends StatefulWidget {
  const AdminReportesScreen({super.key});

  @override
  State<AdminReportesScreen> createState() => _AdminReportesScreenState();
}

class _AdminReportesScreenState extends State<AdminReportesScreen> {
  final _repo = AdminRepository.instance;
  final _lista = GlobalKey<ListaAdminState<AdminReporte>>();
  String _estado = '';

  Future<PaginaAdmin<AdminReporte>> _cargar(int page) =>
      _repo.reportes(estado: _estado, page: page);

  void _filtrar(String v) {
    setState(() => _estado = v);
    _lista.currentState?.recargar();
  }

  // Abre el detalle y traduce su resultado: elevar de nuevo o refrescar la lista.
  Future<void> _abrir(AdminReporte r) async {
    final res = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (_) => _DetalleReporte(reporte: r),
    );
    if (!mounted) return;
    if (res == 'elevacion') {
      Navigator.of(context).pushReplacementNamed('/admin');
    } else if (res == 'guardado') {
      avisoAdmin(context, 'Reporte actualizado');
      _lista.currentState?.recargar(silencioso: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AdminScaffold(
      actual: 'reportes',
      titulo: 'Reportes',
      body: Column(
        children: [
          BarraFiltros(
            filtros: FiltroChips<String>(
              valor: _estado,
              opciones: [
                ('', 'Todos'),
                for (final e in _estados) (e, _etiquetaEstado(e)),
              ],
              onChanged: _filtrar,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: ListaAdmin<AdminReporte>(
              key: _lista,
              cargar: _cargar,
              vacio: _estado.isEmpty
                  ? 'No hay reportes.'
                  : 'No hay reportes con estado "${_etiquetaEstado(_estado)}".',
              iconoVacio: Icons.flag_outlined,
              itemBuilder: (_, r) =>
                  _TarjetaReporte(r: r, onTap: () => _abrir(r)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Resumen de un reporte en la lista; el acento de la tarjeta sigue al estado.
class _TarjetaReporte extends StatelessWidget {
  final AdminReporte r;
  final VoidCallback onTap;
  const _TarjetaReporte({required this.r, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = _colorEstado(r.estado);
    return TarjetaAdmin(
      acento: color,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.flag_rounded, size: 18, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  r.titulo,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.poppins(
                    15,
                    weight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              PildoraEstado(texto: _etiquetaEstado(r.estado), color: color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _etiquetaTipo(r.tipo),
            style: AppText.poppins(13, color: AppColors.texto2),
          ),
          const SizedBox(height: 4),
          Text(
            'Reporta: ${r.usuario} · ${formatearFecha(r.fecha)}',
            style: AppText.poppins(12.5, color: AppColors.texto2, height: 1.4),
          ),
          if (r.reportado != null) ...[
            const SizedBox(height: 2),
            Text(
              'Contra: ${r.reportado}',
              style: AppText.poppins(
                12.5,
                weight: FontWeight.w600,
                color: AppColors.errorTexto,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Devuelve 'guardado' o 'elevacion' (venció el acceso de administrador).
class _DetalleReporte extends StatefulWidget {
  final AdminReporte reporte;
  const _DetalleReporte({required this.reporte});

  @override
  State<_DetalleReporte> createState() => _DetalleReporteState();
}

class _DetalleReporteState extends State<_DetalleReporte> {
  // Estado y notas se editan en local hasta pulsar "Guardar cambios".
  late String _estado = widget.reporte.estado;
  late final _notas = TextEditingController(text: widget.reporte.notas ?? '');
  bool _guardando = false;
  String? _aviso;

  @override
  void dispose() {
    _notas.dispose();
    super.dispose();
  }

  // Un enlace roto o sin app compatible no debe romper la hoja.
  Future<void> _abrirEnlace(String url) async {
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  // Guarda estado y notas; si la elevación venció, cierra la hoja para volver a la puerta.
  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _guardando = true;
      _aviso = null;
    });
    try {
      await AdminRepository.instance.actualizarReporte(
        widget.reporte.id,
        _estado,
        _notas.text.trim(),
      );
      if (mounted) Navigator.of(context).pop('guardado');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.requiereElevacion) {
        AdminRepository.instance.salir();
        Navigator.of(context).pop('elevacion');
        return;
      }
      setState(() {
        _guardando = false;
        _aviso = e.mensaje;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.reporte;
    OutlineInputBorder borde(Color c, [double w = 1.2]) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: c, width: w),
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            20 + MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(r.titulo, style: AppText.serif(24, height: 1.15)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  PildoraEstado(
                    texto: _etiquetaTipo(r.tipo),
                    color: AppColors.texto2,
                  ),
                  PildoraEstado(
                    texto: _etiquetaEstado(r.estado),
                    color: _colorEstado(r.estado),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.bg2,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borde),
                ),
                child: Text(
                  r.descripcion,
                  style: AppText.poppins(14, height: 1.55),
                ),
              ),
              // Evidencias: imágenes ampliables con zoom o enlaces externos.
              if (r.evidencias.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(
                  'Evidencia adjunta',
                  style: AppText.poppins(
                    13,
                    weight: FontWeight.w600,
                    color: AppColors.texto2,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (var i = 0; i < r.evidencias.length; i++)
                      if (_esImagen.hasMatch(r.evidencias[i]))
                        Semantics(
                          button: true,
                          label: 'Ver evidencia ${i + 1}',
                          child: GestureDetector(
                            onTap: () =>
                                verImagenAdmin(context, r.evidencias[i]),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: SizedBox(
                                width: 84,
                                height: 84,
                                child: Image.network(
                                  r.evidencias[i],
                                  fit: BoxFit.cover,
                                  cacheWidth: 220,
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
                        )
                      else
                        BotonAdmin(
                          label: 'Enlace ${i + 1}',
                          icono: Icons.link_rounded,
                          color: AppColors.texto2,
                          onTap: () => _abrirEnlace(r.evidencias[i]),
                        ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              FilaDatoAdmin(
                'Reporta',
                r.correoUsuario == null
                    ? r.usuario
                    : '${r.usuario}\n${r.correoUsuario}',
              ),
              if (r.reportado != null)
                FilaDatoAdmin(
                  'Reportado',
                  [
                    r.reportado!,
                    if (r.correoReportado != null) r.correoReportado!,
                    if (r.reportadoActivo == false) 'Cuenta suspendida',
                  ].join('\n'),
                ),
              if (r.tituloServicio != null)
                FilaDatoAdmin('Servicio', r.tituloServicio!),
              FilaDatoAdmin('Fecha', formatearFecha(r.fecha)),
              if (r.adminResponde != null)
                FilaDatoAdmin('Atendido por', r.adminResponde!),
              if (r.fechaResolucion != null)
                FilaDatoAdmin('Resuelto', formatearFecha(r.fechaResolucion)),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borde),
              const SizedBox(height: 16),
              // --- Gestión: estado y notas ---
              Semantics(
                header: true,
                child: Text(
                  'Gestionar reporte',
                  style: AppText.poppins(15, weight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 12),
              FiltroChips<String>(
                envolver: true,
                valor: _estado,
                opciones: [for (final e in _estados) (e, _etiquetaEstado(e))],
                onChanged: (v) => setState(() => _estado = v),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _notas,
                minLines: 3,
                maxLines: 6,
                maxLength: 2000,
                cursorColor: AppColors.admin,
                style: AppText.poppins(14.5, height: 1.5),
                decoration: InputDecoration(
                  filled: true,
                  fillColor: AppColors.bg2,
                  hintText: 'Notas de resolución (opcional)',
                  hintStyle: AppText.poppins(
                    14.5,
                    color: AppColors.placeholder,
                  ),
                  counterStyle: AppText.poppins(11.5, color: AppColors.texto3),
                  enabledBorder: borde(AppColors.bordeCampo),
                  focusedBorder: borde(AppColors.admin, 1.6),
                ),
              ),
              const SizedBox(height: 8),
              AuthAviso(mensaje: _aviso),
              AuthPrimaryButton(
                label: 'Guardar cambios',
                color: AppColors.admin,
                colorHover: AppColors.adminHover,
                cargando: _guardando,
                onTap: _guardar,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
