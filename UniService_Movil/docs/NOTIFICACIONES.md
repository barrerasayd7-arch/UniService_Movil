# Campana de notificaciones

Reiniciar la API y la app para habilitar `GET /api/notificaciones`. No requiere una
migración nueva: consulta las tablas de solicitudes, servicios y calificaciones existentes.

La campana muestra hasta 100 avisos recientes de la cuenta autenticada:

- Solicitud pendiente o cancelada: se avisa al proveedor y abre Recibidas.
- Solicitud aceptada, rechazada o completada: se avisa al cliente y abre Enviadas.
- Servicio aprobado o rechazado con fecha de revisión: abre Mis servicios.
- Reseña recibida o editada: abre el servicio correspondiente.

Los avisos reflejan el último estado disponible de cada registro. No constituyen un
historial completo de transiciones; al cambiar el estado o eliminar el registro puede
dejar de aparecer el aviso anterior. No se inventan fechas para registros antiguos.

La campana actualiza al abrirse, al volver al inicio, al reanudar la app y cada 10 segundos
mientras el inicio está visible. También escucha los cambios de chats y las acciones de
solicitudes de esta app. Los cambios remotos sin evento de chat llegan mediante la consulta
periódica. No implementa notificaciones push del sistema con la app cerrada.

Tocar un aviso lo marca como leído y abre su sección. Hay acciones para marcar todos
como leídos, actualizar y descartar los avisos visibles. Descartar no elimina solicitudes,
servicios, reseñas ni mensajes.

La lectura y el descarte se guardan usando el almacenamiento seguro existente, separados
por cuenta y URL de la API, hasta 2.000 identificadores de cada tipo. Se conservan al
reiniciar en el mismo dispositivo; no se sincronizan entre dispositivos. Un fallo de
almacenamiento se informa en el panel. Al cambiar de cuenta se borran inmediatamente los
avisos de memoria y se ignoran respuestas pendientes de la sesión anterior.

Prueba manual: iniciar sesión con cliente y proveedor; crear una solicitud, revisar la
campana del proveedor, aceptarla y revisar la del cliente. Marcar leída, reiniciar la app
y comprobar que no vuelve a contarse. Probar cambio de cuenta, error de red y descarte.
Para reseñas y moderación, usar los flujos existentes y volver al inicio.
