import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'detail_widgets.dart';
import 'form_solicitud.dart' show CampoCaja;

/// Formulario para calificar el servicio (estrellas + comentario opcional).
/// Tres estados, igual que en la web:
///  1. puede calificar  -> "Dejar una reseña"
///  2. ya calificó      -> muestra su reseña con botón "Editar"
///  3. editando         -> "Editar reseña"
/// (Cuando el usuario no tiene permiso, la web no muestra nada.)
class FormCalificacion extends StatefulWidget {
  /// Se llama al publicar una reseña nueva (para agregarla a la lista).
  final void Function(int estrellas, String comentario) onNuevaResena;

  /// Si es false el formulario no se muestra (el usuario no ha usado el servicio).
  final bool puedeCalificar;

  const FormCalificacion({
    super.key,
    required this.onNuevaResena,
    this.puedeCalificar = true,
  });

  @override
  State<FormCalificacion> createState() => _FormCalificacionState();
}

class _FormCalificacionState extends State<FormCalificacion> {
  int _estrellas = 0;
  int _hover = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;
  bool _yaCalifico = false;
  bool _editando = false;
  String _fecha = '';

  // Valores guardados (para restaurar al cancelar la edición)
  int _estrellasGuardadas = 0;
  String _comentarioGuardado = '';

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  String _hoy() {
    const meses = [
      'enero', 'febrero', 'marzo', 'abril', 'mayo', 'junio',
      'julio', 'agosto', 'septiembre', 'octubre', 'noviembre', 'diciembre',
    ];
    final d = DateTime.now();
    return '${d.day} de ${meses[d.month - 1]} de ${d.year}';
  }

  Future<void> _enviar({required bool actualizar}) async {
    if (_estrellas == 0) {
      mostrarNotificacion(context, 'Selecciona una puntuación');
      return;
    }
    setState(() => _enviando = true);
    
    await Future<void>.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _enviando = false;
      _yaCalifico = true;
      _editando = false;
      _fecha = _hoy();
      _estrellasGuardadas = _estrellas;
      _comentarioGuardado = _comentario.text.trim();
    });
    mostrarNotificacion(
      context,
      actualizar ? '¡Reseña actualizada!' : '¡Reseña enviada!',
      exito: true,
    );
    if (!actualizar) widget.onNuevaResena(_estrellas, _comentario.text.trim());
  }

  /// Selector de estrellas grande con efecto hover (★ de 32px).
  Widget _selector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          for (var n = 1; n <= 5; n++)
            Padding(
              padding: EdgeInsets.only(right: n < 5 ? 8 : 0),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hover = n),
                onExit: (_) => setState(() => _hover = 0),
                child: GestureDetector(
                  onTap: () => setState(() => _estrellas = n),
                  child: Text(
                    '★',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.1,
                      color: n <= (_hover != 0 ? _hover : _estrellas)
                          ? const Color(0xFFFBBF24)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _cajaComentario() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: CampoCaja(
        lleno: _comentario.text.trim().isNotEmpty,
        child: TextField(
          controller: _comentario,
          onChanged: (_) => setState(() {}),
          minLines: 3,
          maxLines: 6,
          cursorColor: AppColors.teal,
          style: AppText.poppins(14.08, height: 1.6),
          decoration: InputDecoration(
            isDense: true,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
            hintText: 'Cuéntanos tu experiencia... (opcional)',
            hintStyle: AppText.poppins(14.08, color: AppColors.texto3),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.puedeCalificar && !_yaCalifico) return const SizedBox.shrink();

    // ── 3. Editando ──
    if (_yaCalifico && _editando) {
      return SeccionInfo(
        icono: Icons.edit_note,
        titulo: 'Editar reseña',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _selector(),
            _cajaComentario(),
            Row(
              children: [
                Expanded(
                  child: BtnDetalle(
                    label: _enviando ? 'Guardando...' : 'Guardar cambios',
                    icono: Icons.check,
                    cargando: _enviando,
                    margenInferior: false,
                    onTap: () => _enviar(actualizar: true),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BtnDetalle(
                    label: 'Cancelar',
                    estilo: EstiloBtn.secundario,
                    margenInferior: false,
                    onTap: () => setState(() {
                      _editando = false;
                      _estrellas = _estrellasGuardadas;
                      _comentario.text = _comentarioGuardado;
                    }),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // ── 2. Ya calificó ──
    if (_yaCalifico) {
      return SeccionInfo(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppColors.teal),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Ya calificaste este servicio',
                          style: AppText.poppins(14.4, color: AppColors.teal),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      for (var n = 1; n <= 5; n++)
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Text(
                            '★',
                            style: TextStyle(
                              fontSize: 20,
                              height: 1.1,
                              color: n <= _estrellasGuardadas
                                  ? const Color(0xFFFBBF24)
                                  : const Color(0xFFCCCCCC),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (_comentarioGuardado.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        _comentarioGuardado,
                        style: AppText.poppins(14, color: const Color(0xFF8FA3BF)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'Publicada el $_fecha',
                      style: AppText.poppins(12, color: AppColors.texto3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 110,
              child: BtnDetalle(
                label: 'Editar',
                icono: Icons.edit_outlined,
                estilo: EstiloBtn.secundario,
                margenInferior: false,
                onTap: () => setState(() => _editando = true),
              ),
            ),
          ],
        ),
      );
    }

    // ── 1. Puede calificar ──
    return SeccionInfo(
      icono: Icons.star_rounded,
      titulo: 'Dejar una reseña',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selector(),
          _cajaComentario(),
          BtnDetalle(
            label: _enviando ? 'Enviando...' : 'Publicar reseña',
            icono: Icons.send_outlined,
            cargando: _enviando,
            margenInferior: false,
            onTap: () => _enviar(actualizar: false),
          ),
        ],
      ),
    );
  }
}
