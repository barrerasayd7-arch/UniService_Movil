import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/chat.dart';
import '../../widgets/avatar_respaldo.dart';

String horaChat(DateTime? fecha) => fecha == null
    ? ''
    : '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

String fechaChat(DateTime? fecha) {
  if (fecha == null) return '';
  final hoy = DateTime.now();
  if (fecha.year == hoy.year &&
      fecha.month == hoy.month &&
      fecha.day == hoy.day) {
    return horaChat(fecha);
  }
  return '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year}';
}

class AvatarChat extends StatelessWidget {
  const AvatarChat({super.key, required this.contacto, this.radio = 24});
  final ContactoChat contacto;
  final double radio;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: radio * 2,
    child: ClipOval(
      child: contacto.avatar == null
          ? ColoredBox(
              color: AppColors.of(context).bg3,
              child: Center(
                child: Text(
                  contacto.nombre.trim().isEmpty
                      ? '?'
                      : contacto.nombre.trim().characters.first.toUpperCase(),
                  style: AppText.poppins(
                    radio * .8,
                    weight: FontWeight.w600,
                    color: AppColors.of(context).tealBrillante,
                  ),
                ),
              ),
            )
          : Image.network(
              contacto.avatar!,
              fit: BoxFit.cover,
              errorBuilder: avatarRespaldo,
            ),
    ),
  );
}

class AvisoChat extends StatelessWidget {
  const AvisoChat({super.key, required this.texto, required this.onReintentar});
  final String texto;
  final VoidCallback onReintentar;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.of(context).bg3,
    child: Wrap(
      spacing: 12,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          texto,
          style: AppText.poppins(13, color: AppColors.of(context).errorTexto),
        ),
        TextButton(onPressed: onReintentar, child: const Text('Actualizar')),
      ],
    ),
  );
}

class BurbujaMensaje extends StatelessWidget {
  const BurbujaMensaje({super.key, required this.mensaje, required this.esMio});
  final MensajeChat mensaje;
  final bool esMio;

  @override
  Widget build(BuildContext context) {
    if (mensaje.esSistema) {
      return Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.of(context).bg3,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long_outlined,
                color: AppColors.of(context).amarillo,
                size: 20,
              ),
              const SizedBox(height: 8),
              SelectableText(
                mensaje.texto,
                textAlign: TextAlign.center,
                style: AppText.poppins(13, color: AppColors.of(context).texto2),
              ),
              const SizedBox(height: 6),
              Text(
                '${fechaChat(mensaje.fecha)} · Solicitud',
                style: AppText.poppins(11, color: AppColors.of(context).texto2),
              ),
            ],
          ),
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, box) => Align(
        alignment: esMio ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: (box.maxWidth * .85).clamp(0, 560),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
          decoration: BoxDecoration(
            color: esMio
                ? AppColors.of(context).mensajePropio
                : AppColors.of(context).card,
            border: Border.all(
              color: esMio
                  ? AppColors.of(
                      context,
                    ).elegir(const Color(0xFF176466), const Color(0xFFA8D5CF))
                  : AppColors.of(context).borde,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText(
                mensaje.texto,
                style: AppText.poppins(
                  14,
                  color: AppColors.of(context).texto,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    horaChat(mensaje.fecha),
                    style: AppText.poppins(
                      10,
                      color: AppColors.of(context).texto2,
                    ),
                  ),
                  if (esMio) ...[
                    const SizedBox(width: 5),
                    Tooltip(
                      message: mensaje.leido ? 'Leído' : 'Enviado',
                      child: Icon(
                        mensaje.leido
                            ? Icons.done_all_rounded
                            : Icons.check_rounded,
                        size: 16,
                        color: mensaje.leido
                            ? AppColors.of(context).tealBrillante
                            : AppColors.of(context).texto2,
                        semanticLabel: mensaje.leido ? 'Leído' : 'Enviado',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
