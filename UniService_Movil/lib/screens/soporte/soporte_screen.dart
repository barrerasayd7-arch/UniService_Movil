import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/app_text.dart';
import 'contenido_legal.dart';

enum PaginaSoporte {
  ayuda('/ayuda', 'Centro de ayuda'),
  terminos('/terminos', 'Términos y Condiciones'),
  privacidad('/privacidad', 'Política de Privacidad'),
  contacto('/contacto', 'Contacto');

  const PaginaSoporte(this.ruta, this.titulo);
  final String ruta;
  final String titulo;
}

const _preguntas = <SeccionInformativa>[
  (
    titulo: '¿Cómo creo una cuenta?',
    texto:
        'Desde Crear cuenta, utiliza tu correo institucional @unicesar.edu.co y verifica el código que recibas. Completa tus datos y consulta los términos y la política de privacidad antes de aceptarlos.',
  ),
  (
    titulo: '¿Cómo publico o edito un servicio?',
    texto:
        'Inicia sesión y entra en Publicar servicio. Completa los datos y añade hasta cinco fotos. La publicación pasa por revisión del administrador. En Mis servicios puedes consultar su estado, editarla y ver las acciones disponibles. Al editar el contenido, el servicio vuelve a revisión.',
  ),
  (
    titulo: '¿Cómo solicito un servicio?',
    texto:
        'Abre un servicio, describe lo que necesitas y envía tu presupuesto desde el formulario de solicitud. Consulta el seguimiento en Solicitudes → Enviadas. Quien ofrece el servicio lo verá en Recibidas.',
  ),
  (
    titulo: '¿Cómo funcionan las contraofertas?',
    texto:
        'El proveedor puede aceptar el presupuesto original o usar Contraoferta para proponer otro precio. El cliente acepta o rechaza el precio desde Enviadas. Si lo acepta, el proveedor debe confirmar el servicio desde Recibidas. Hasta entonces, la solicitud sigue pendiente.',
  ),
  (
    titulo: '¿Dónde veo mensajes y notificaciones?',
    texto:
        'En el inicio encontrarás los accesos a chats y a la campana. También puedes abrir el chat desde una solicitud. Los avisos se consultan dentro de la app; por ahora no se envían notificaciones push con la app cerrada.',
  ),
  (
    titulo: '¿Cómo recupero mi contraseña?',
    texto:
        'En Iniciar sesión, pulsa ¿Olvidaste tu contraseña? e introduce tu correo institucional. Revisa tu bandeja de entrada y spam. Verifica el código y escribe tu nueva contraseña. Si aparece un error de envío, espera e inténtalo de nuevo.',
  ),
  (
    titulo: '¿Cómo reporto un servicio o califico una experiencia?',
    texto:
        'Puedes reportar un servicio desde su detalle indicando el motivo. Para calificar, primero debe completarse una solicitud tuya de ese servicio. Después podrás dejar tu puntuación y comentario.',
  ),
];

/// Información pública, disponible sin iniciar sesión y sin consultar la API.
class SoporteScreen extends StatelessWidget {
  final PaginaSoporte pagina;
  const SoporteScreen({super.key, required this.pagina});

  @override
  Widget build(BuildContext context) {
    final legal =
        pagina == PaginaSoporte.terminos || pagina == PaginaSoporte.privacidad;
    return Scaffold(
      appBar: AppBar(
        title: const Text('UniService'),
        leading: IconButton(
          tooltip: 'Volver',
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            final nav = Navigator.of(context);
            if (nav.canPop()) {
              nav.pop();
            } else {
              nav.pushReplacementNamed('/home-guest');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 860),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(pagina.titulo, style: AppText.serif(32)),
                    ),
                    const SizedBox(height: 24),
                    if (legal) ..._legal(context),
                    if (pagina == PaginaSoporte.ayuda) ...[
                      _parrafo(
                        context,
                        'Encuentra respuestas sobre tu cuenta, tus publicaciones y tus solicitudes.',
                      ),
                      const SizedBox(height: 16),
                      for (final pregunta in _preguntas)
                        Card(
                          clipBehavior: Clip.antiAlias,
                          child: ExpansionTile(
                            title: Text(
                              pregunta.titulo,
                              style: AppText.poppins(
                                15,
                                weight: FontWeight.w600,
                              ),
                            ),
                            expandedCrossAxisAlignment:
                                CrossAxisAlignment.start,
                            childrenPadding: const EdgeInsets.fromLTRB(
                              16,
                              0,
                              16,
                              20,
                            ),
                            children: [_parrafo(context, pregunta.texto)],
                          ),
                        ),
                    ],
                    if (pagina == PaginaSoporte.contacto) ...[
                      Icon(
                        Icons.support_agent,
                        size: 48,
                        color: AppColors.of(context).teal,
                      ),
                      const SizedBox(height: 16),
                      _parrafo(
                        context,
                        'Los canales oficiales de contacto aún no están disponibles. Publicaremos aquí la información de atención cuando esté definida.',
                      ),
                      const SizedBox(height: 16),
                      _parrafo(
                        context,
                        'Mientras tanto, puedes consultar el Centro de ayuda. Si necesitas reportar un servicio, utiliza la opción Reportar en su detalle.',
                      ),
                    ],
                    const SizedBox(height: 32),
                    const Divider(),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final otra in PaginaSoporte.values)
                          if (otra != pagina)
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(context).pushNamed(otra.ruta),
                              child: Text(otra.titulo),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _legal(BuildContext context) {
    final esTerminos = pagina == PaginaSoporte.terminos;
    return [
      _parrafo(
        context,
        esTerminos ? introduccionTerminos : introduccionPrivacidad,
      ),
      for (final seccion in esTerminos ? terminos : privacidad) ...[
        const SizedBox(height: 28),
        Semantics(
          header: true,
          child: Text(
            seccion.titulo,
            style: AppText.poppins(19, weight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 10),
        _parrafo(context, seccion.texto),
      ],
      if (!esTerminos) ...[
        const SizedBox(height: 24),
        _parrafo(context, avisoPrivacidad, destacado: true),
      ],
    ];
  }

  Widget _parrafo(
    BuildContext context,
    String texto, {
    bool destacado = false,
  }) => SelectableText(
    texto,
    style: AppText.poppins(
      15,
      color: AppColors.of(context).texto2,
      height: 1.7,
      weight: destacado ? FontWeight.w600 : FontWeight.w400,
    ),
  );
}
