import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import '../../models/servicio_detalle.dart';
import '../../widgets/app_buttons.dart' show HoverBuilder;
import 'detail_widgets.dart';

/// Colores del avatar según la primera letra (colorAvatar de utilidades.js).
const _coloresAvatar = [
  [Color(0xFF3B82F6), Color(0xFF60A5FA)], // ag-azul
  [Color(0xFF8B5CF6), Color(0xFFA78BFA)], // ag-morado
  [Color(0xFF0EA5A0), Color(0xFF14C7C1)], // ag-verde
  [Color(0xFFF97316), Color(0xFFFB923C)], // ag-naranja
];

List<Color> colorAvatar(String? nombre) {
  if (nombre == null || nombre.isEmpty) return _coloresAvatar[0];
  return _coloresAvatar[nombre.codeUnitAt(0) % _coloresAvatar.length];
}

/// `.card-proveedor`: avatar, nombre, universidad y calificación.
class ProveedorCard extends StatelessWidget {
  final ServicioDetalle detalle;
  final VoidCallback onTap;
  const ProveedorCard({super.key, required this.detalle, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final s = detalle.servicio;
    final ancho = MediaQuery.of(context).size.width;
    final movil = ancho <= 540;
    final avatar = movil ? 52.0 : 64.0;
    final colores = colorAvatar(s.proveedor);

    return HoverBuilder(
      builder: (context, hover) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          transform: Matrix4.translationValues(0, hover ? -3 : 0, 0),
          margin: const EdgeInsets.only(bottom: 24),
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.all(movil ? 16 : 24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: hover ? AppColors.a(AppColors.teal, 0.4) : AppColors.borde,
            ),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0, 0.5, 1],
              colors: [
                const Color(0xFF0E1929),
                Color.alphaBlend(AppColors.a(AppColors.teal, 0.05), const Color(0xFF0E1929)),
                Color.alphaBlend(AppColors.a(AppColors.violeta, 0.03), const Color(0xFF0E1929)),
              ],
            ),
            boxShadow: hover
                ? [
                    BoxShadow(
                      color: AppColors.a(AppColors.teal, 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha(51),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const [],
          ),
          child: Stack(
            children: [
              // Resplandor que aparece al pasar el cursor
              Positioned(
                top: -80,
                right: -80,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 250),
                  opacity: hover ? 1 : 0,
                  child: Container(
                    width: 220,
                    height: 220,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [AppColors.a(AppColors.teal, 0.08), Colors.transparent],
                        stops: const [0, 0.7],
                      ),
                    ),
                  ),
                ),
              ),
              Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: avatar,
                        height: avatar,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: colores,
                          ),
                          border: Border.all(color: Colors.white.withAlpha(26), width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha(77),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'assets/img/default-avatar.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      SizedBox(width: movil ? 12 : 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              s.proveedor.isEmpty ? 'Proveedor anónimo' : s.proveedor,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(
                                movil ? 15.2 : 17.6,
                                weight: FontWeight.w700,
                                color: hover ? AppColors.teal : AppColors.texto,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              detalle.universidadTexto,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppText.poppins(13.6, color: AppColors.texto2),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.only(top: 14),
                    decoration: BoxDecoration(
                      border: Border(top: BorderSide(color: Colors.white.withAlpha(15))),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha(10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: AppColors.estrella),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    '${s.estrellas} · ${detalle.resenas.length} reseñas',
                                    overflow: TextOverflow.ellipsis,
                                    style: AppText.poppins(
                                      13.12,
                                      weight: FontWeight.w500,
                                      color: AppColors.texto2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        // "Ver perfil →" aparece al pasar el cursor
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 250),
                          opacity: hover ? 1 : 0,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            transform: Matrix4.translationValues(hover ? 0 : -8, 0, 0),
                            child: Text(
                              'Ver perfil →',
                              style: AppText.poppins(
                                12.8,
                                weight: FontWeight.w600,
                                color: AppColors.teal,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.contacto-botones`: Gmail (si el contacto es un correo) o WhatsApp
/// (si es un teléfono) + "Enviar mensaje".
class ContactoBotones extends StatelessWidget {
  final String contacto;
  final VoidCallback onContactar;
  final VoidCallback onMensaje;
  const ContactoBotones({
    super.key,
    required this.contacto,
    required this.onContactar,
    required this.onMensaje,
  });

  @override
  Widget build(BuildContext context) {
    final esCorreo = contacto.contains('@');
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          BtnDetalle(
            label: esCorreo ? 'Contactar por Gmail' : 'Contactar por WhatsApp',
            icono: esCorreo ? Icons.mail : Icons.message,
            estilo: esCorreo ? EstiloBtn.gmail : EstiloBtn.whatsapp,
            onTap: onContactar,
          ),
          BtnDetalle(
            label: 'Enviar mensaje',
            icono: Icons.chat_bubble,
            onTap: onMensaje,
          ),
        ],
      ),
    );
  }
}
