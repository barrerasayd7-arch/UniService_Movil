# Contraofertas de solicitudes

## Antes de probar

Aplicar `database/migrations/011_contraofertas_solicitudes.sql` sobre la misma base de
la API, después de las migraciones anteriores y **antes de arrancar el backend nuevo**.
Reiniciar API y app. Este archivo no se ejecuta automáticamente: sin las columnas nuevas
las consultas de solicitudes y notificaciones no funcionarán.

La migración se puede repetir y conserva negociaciones existentes, presupuestos y precios
de solicitudes antiguas. No se ha ejecutado sobre datos reales durante el desarrollo.

## Flujo

1. El cliente envía su presupuesto. El proveedor ve Chatear, Rechazar, Aceptar y Contraoferta.
2. Aceptar confirma el presupuesto original, sin campo para otro precio.
3. Contraoferta propone un precio entre 1 y 99.999.999 pesos enteros. No acepta el servicio.
4. El cliente recibe un aviso en su campana y responde desde Enviadas: aceptar o rechazar precio.
5. Si acepta, el proveedor recibe el aviso y debe pulsar Aceptar desde Recibidas.
6. Sólo tras esa confirmación el servicio queda Aceptado y puede completarse.
7. Si rechaza el precio, el proveedor puede aceptar el presupuesto original o proponer otro precio.

Durante la negociación el estado principal sigue siendo `Pendiente`; los filtros existentes
incluyen esas solicitudes. El cliente puede cancelar y el proveedor puede rechazar la solicitud.
No se permite sustituir una oferta que está pendiente de respuesta o ya aprobada.

## Datos y API

`presupuesto` conserva el importe original. `contraoferta` guarda el último precio propuesto.
`estado_contraoferta` es null, `pendiente`, `aceptada` o `rechazada`.
`version_contraoferta` comienza en 0 y sube al proponer otro precio.

| POST `/api/solicitudes/{id}/…` | Actor | Cuerpo |
|---|---|---|
| `aceptar` | Proveedor | `{"version_contraoferta":0}` o la versión vigente |
| `contraoferta` | Proveedor | `{"precio":50000,"version_contraoferta":0}` |
| `aceptar-contraoferta` | Cliente | `{"version_contraoferta":1}` |
| `rechazar-contraoferta` | Cliente | `{"version_contraoferta":1}` |

La API valida rol, estado y versión bajo bloqueo de fila: una pantalla antigua recibe 409
y no puede confirmar un precio diferente. El antiguo cuerpo `aceptar` con precio recibe 400.
Cada paso de negociación y aceptación guarda un mensaje del sistema en el chat en la misma
transacción. SignalR actualiza la bandeja y la campana; hay recuperación por consulta periódica
y al volver a la pantalla. Los avisos son dentro de la app, no push con la app cerrada.

## Prueba con dos cuentas

- Solicitar por $40.000 y aceptar directamente: confirmar que el precio se conserva.
- Crear otra solicitud, proponer $50.000 y comprobar el aviso del cliente.
- Aceptar el precio desde el cliente: debe seguir Pendiente y avisar al proveedor.
- Confirmar desde el proveedor: pasa a Aceptada y avisa al cliente.
- Probar rechazar el precio, nueva propuesta, cancelar y responder desde una pantalla antigua.
- Revisar ambos chats y volver al inicio para comprobar la campana.

Pruebas de Flutter: `flutter test --no-pub`. SQL local en memoria: `node servicios.mjs`
desde `database/tests`. La suite HTTP `UniserviceAPI/tests/servicios-e2e/run.mjs` requiere
Docker y utiliza una base desechable, no Supabase.
