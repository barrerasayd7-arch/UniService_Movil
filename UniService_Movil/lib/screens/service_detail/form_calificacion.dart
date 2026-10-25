// Archivo: form_calificacion.dart
// Responsabilidad: reseña del servicio (estrellas y comentario), con alta y edición.
// Se usa desde: detail_screen, debajo de la lista de reseñas.

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../core/categorias.dart' show formatearFecha;
import '../../data/api_client.dart';
import '../../data/solicitudes_repository.dart';
import '../../models/solicitud.dart';
import '../login/auth_widgets.dart' show mostrarNotificacion;
import 'detail_widgets.dart';
import 'form_solicitud.dart' show CampoCaja;

/// Reseña del servicio (estrellas + comentario opcional), según
/// `GET /api/calificaciones/estado`:
///  1. puede calificar (tiene una solicitud completada) -> "Dejar una reseña"
///  2. ya calificó -> muestra su reseña con botón "Editar"
///  3. editando    -> "Editar reseña"
/// Si no ha usado el servicio no se muestra nada.
class FormCalificacion extends StatefulWidget {
  final int idServicio;

  /// Se llama tras publicar o editar, para recargar reseñas y promedio.
  final VoidCallback onGuardada;
  final SolicitudesRepository? repositorio;

  const FormCalificacion({
    super.key,
    required this.idServicio,
    required this.onGuardada,
    this.repositorio,
  });

  @override
  State<FormCalificacion> createState() => _FormCalificacionState();
}

class _FormCalificacionState extends State<FormCalificacion> {
  late final SolicitudesRepository _repo =
      widget.repositorio ?? SolicitudesRepository.instance;
  EstadoCalificacion _estado = EstadoCalificacion.ninguno;
  int _estrellas = 0;
  final _comentario = TextEditingController();
  bool _enviando = false;
  bool _editando = false; // cambia la vista entre "ver" y "editar" la reseña

  @override
  void initState() {
    super.initState();
    _consultar();
  }

  @override
  void dispose() {
    _comentario.dispose();
    super.dispose();
  }

  /// Pregunta a la API si puede calificar, ya calificó o no aplica.
  Future<void> _consultar() async {
    try {
      final e = await _repo.estadoCalificacion(widget.idServicio);
      if (mounted) setState(() => _estado = e);
    } on ApiException {
      // Sin estado no se muestra el formulario.
    }
  }

  /// Crea o actualiza la reseña según haya `idCalificacion`; al terminar
  /// refresca el estado y avisa al detalle para recargar promedio y lista.
  Future<void> _enviar() async {
    if (_estrellas == 0) {
      mostrarNotificacion(context, 'Selecciona una puntuación');
      return;
    }
    setState(() => _enviando = true);
    final id = _estado.idCalificacion;
    try {
      if (id == null) {
        await _repo.calificar(widget.idServicio, _estrellas, _comentario.text);
      } else {
        await _repo.editarCalificacion(id, _estrellas, _comentario.text);
      }
      await _consultar();
      if (!mounted) return;
      setState(() => _editando = false);
      mostrarNotificacion(
        context,
        id == null ? '¡Reseña publicada!' : '¡Reseña actualizada!',
        exito: true,
      );
      widget.onGuardada();
    } on ApiException catch (e) {
      if (mounted) mostrarNotificacion(context, e.mensaje);
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  /// Precarga la reseña existente en los controles de edición.
  void _empezarEdicion() => setState(() {
    _editando = true;
    _estrellas = _estado.puntuacion;
    _comentario.text = _estado.comentario;
  });

  /// Selector de estrellas grande (48 px de área táctil por estrella).
  Widget _selector() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          for (var n = 1; n <= 5; n++)
            Semantics(
              button: true,
              selected: n <= _estrellas,
              label: '$n ${n == 1 ? 'estrella' : 'estrellas'}',
              child: InkResponse(
                onTap: () => setState(() => _estrellas = n),
                radius: 24,
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(
                    n <= _estrellas ? Icons.star_rounded : Icons.star_outline_rounded,
                    size: 34,
                    color: n <= _estrellas
                        ? AppColors.estrella
                        : const Color(0xFF374151),
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
          maxLength: 1000,
          buildCounter:
              (_, {required currentLength, required isFocused, maxLength}) =>
                  null,
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
    final e = _estado;
    if (!e.puedeCalificar && !e.yaCalifico) return const SizedBox.shrink();

    // --- Caso 2: ya calificó y no está editando ---
    if (e.yaCalifico && !_editando) {
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
                      const Icon(
                        Icons.check_circle,
                        size: 16,
                        color: AppColors.teal,
                      ),
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
                        Icon(
                          Icons.star_rounded,
                          size: 20,
                          color: n <= e.puntuacion
                              ? AppColors.estrella
                              : const Color(0xFF374151),
                        ),
                    ],
                  ),
                  if (e.comentario.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        e.comentario,
                        style: AppText.poppins(14, color: AppColors.texto2),
                      ),
                    ),
                  if (e.fecha != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        'Publicada el ${formatearFecha(e.fecha)}',
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
                onTap: _empezarEdicion,
              ),
            ),
          ],
        ),
      );
    }

    // --- Casos 1 y 3: puede calificar o está editando ---
    return SeccionInfo(
      icono: _editando ? Icons.edit_note : Icons.star_rounded,
      titulo: _editando ? 'Editar reseña' : 'Dejar una reseña',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _selector(),
          _cajaComentario(),
          if (_editando)
            Row(
              children: [
                Expanded(
                  child: BtnDetalle(
                    label: _enviando ? 'Guardando...' : 'Guardar',
                    icono: Icons.check,
                    cargando: _enviando,
                    margenInferior: false,
                    onTap: _enviar,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: BtnDetalle(
                    label: 'Cancelar',
                    estilo: EstiloBtn.secundario,
                    margenInferior: false,
                    onTap: () => setState(() => _editando = false),
                  ),
                ),
              ],
            )
          else
            BtnDetalle(
              label: _enviando ? 'Enviando...' : 'Publicar reseña',
              icono: Icons.send_outlined,
              cargando: _enviando,
              margenInferior: false,
              onTap: _enviar,
            ),
        ],
      ),
    );
  }
}
