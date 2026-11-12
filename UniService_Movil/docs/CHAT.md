# Chat móvil

## Qué se implementó

- `/chats`: bandeja con búsqueda por nombre, no leídos y último mensaje.
- `/chat`: historial, texto de hasta 2000 caracteres, paginación hacia atrás,
  mensajes del sistema de solicitudes y confirmaciones de lectura.
- Accesos desde el botón flotante del inicio, el perfil del proveedor, el detalle
  del servicio, la solicitud activa y las tarjetas de solicitudes.
- El contador del botón de chat usa `GET /api/chat/no-leidos`.
- Tiempo real mediante `signalr_netcore` y el hub existente `/chathub`, con JWT.
- Recuperación por REST al reconectar y actualización de respaldo cada 10 segundos
  mientras la pantalla está visible. El contador global se verifica cada 20 segundos.
- La conexión se cierra en segundo plano y al salir de la cuenta. Una conversación
  tapada por otra pantalla no marca mensajes nuevos como leídos.
- El borrador se conserva si el envío falla. No hay reenvíos automáticos, porque un
  fallo de red puede ocurrir después de guardar el mensaje en el servidor.

La campana de notificaciones generales sigue fuera de este módulo. El chat actual
envía texto; no se añadieron archivos, audio, edición ni eliminación de mensajes.
La bandeja conserva el límite de 200 conversaciones establecido por el backend.

## Componentes

`models/chat.dart` interpreta las respuestas del backend y define `DestinoChat`.
`ChatRepository` encapsula REST y notifica cambios. `ChatRealtime` traduce los eventos
`RecibirMensaje` y `MensajesLeidos` en actualizaciones del repositorio.
`ChatSession` enlaza conexión, sesión, contador y ciclo de vida de la app.
`ConversacionController` fusiona mensajes por id y recupera las páginas perdidas al
reconectar; mantiene el estado del historial separado de los widgets.
`ApiClient` ignora para el cierre de sesión los rechazos tardíos de peticiones que
se hicieron con un token anterior, para proteger el cambio de cuenta.

Las pantallas usan las rutas protegidas de `main.dart`. La identidad del remitente
la obtiene el servidor del JWT; Flutter sólo envía el texto del mensaje.

En el backend, `SolicitudesController` ahora avisa a los grupos de ambos usuarios
cuando crea un mensaje del sistema. Así la bandeja puede actualizarse sin que los
participantes hayan abierto antes esa conversación. No hay migraciones nuevas.

Referencia de la dependencia: [signalr_netcore](https://pub.dev/packages/signalr_netcore).

## Cómo probar con dos cuentas

1. Reinicia la API para cargar el cambio de `SolicitudesController`. Si ya hay una
   instancia en ejecución, detenla con Ctrl+C en su terminal antes de `dotnet run`.
2. En `UniService_Movil`, ejecuta `flutter pub get` y reinicia completamente la app
   (se añadió una dependencia; no basta con hot reload).
3. Usa dos cuentas activas y con correo institucional verificado en dos dispositivos
   o perfiles de navegador separados. Dos pestañas del mismo perfil comparten
   almacenamiento de sesión y no son una buena prueba de cuentas independientes.
4. En la primera cuenta, abre un servicio o el perfil de la segunda y toca el botón
   de chat. Envía un mensaje. Comprueba el contador y la conversación en la segunda.
5. Responde desde la segunda y verifica que aparece sin recargar manualmente.
   Al abrir el chat, los mensajes del remitente deben mostrar la confirmación de leído.
6. Envía una solicitud de servicio y comprueba que su resumen aparece en el historial.
7. Abre el perfil desde la cabecera del chat, envía otro mensaje desde el otro
   dispositivo y vuelve: debe marcarse leído al regresar, no mientras estaba oculto.
8. Desconecta temporalmente la red: el borrador debe conservarse si intentas enviar.
   Al recuperar conexión, actualiza el historial antes de reenviar un envío incierto.
9. Con más de 50 mensajes, usa “Cargar mensajes anteriores”. Cierra sesión y entra
   con otra cuenta: el contador y las conversaciones deben corresponder a esa cuenta.

Para Chrome local:

```powershell
flutter run -d chrome --dart-define=API_URL=http://localhost:5165
```

Para emulador Android, usa `http://10.0.2.2:5165`. Para un celular físico, utiliza
la IP accesible del PC y arranca la API con el perfil `celular`. El hosting debe
permitir conexiones al hub `/chathub`; si falla el tiempo real, REST sigue actualizando.

## Validaciones automatizadas

```powershell
flutter test --no-pub
flutter analyze --no-pub
flutter build web --no-pub
```

`chat_test.dart` comprueba contratos HTTP, paginación, deduplicación, recuperación
de huecos, permisos de envío y respuestas tardías. `chat_widgets_test.dart` prueba
búsqueda, envío, borradores, lectura y layouts móvil/escritorio. La prueba de
`chat_realtime_test.dart` abre un servidor WebSocket temporal en loopback para
comprobar negociación SignalR, JWT, eventos y desconexión sin usar Supabase.
