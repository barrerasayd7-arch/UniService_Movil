# API de servicios, solicitudes y calificaciones

Requiere la migración `008_servicios_movil.sql`. El usuario siempre sale del JWT (`Authorization: Bearer …`); la API ignora cualquier `id_proveedor`, `id_cliente` o `id_usuario` enviado en el cuerpo.

**Niveles de acceso**
- **Invitado**: sin token.
- **Sesión**: token válido de una cuenta activa.
- **Verificado**: sesión + correo @unicesar verificado y vigente (180 días). Sin verificación responde `403 "Verifica tu correo institucional para continuar"`.

Los errores siempre llegan como `{ "error": "mensaje para el usuario" }` (y `detalles` en errores de validación); `ApiClient` ya los traduce.

## Servicios — `/api/servicios`

| Método y ruta | Acceso | Qué hace |
|---|---|---|
| `GET /api/servicios?pagina=1&por_pagina=12&categoria=&busqueda=&orden=recientes` | Invitado | Listado público: sólo aprobados de cuentas activas. `orden`: `recientes`, `antiguos`, `precio-menor`, `precio-mayor`, `rating-mayor`, `rating-menor`. Búsqueda sin tildes ni mayúsculas. `por_pagina` ≤ 50 |
| `GET /api/servicios/categorias` | Invitado | `[{ id_categoria, nombre }]` |
| `GET /api/servicios/{id}` | Invitado | Detalle, imágenes, hasta 50 reseñas y estadísticas del proveedor. `contacto`, `direccion` y coordenadas llegan `null` sin sesión. El dueño y los admins ven también servicios no aprobados |
| `GET /api/servicios/mios` | Sesión | Servicios propios en cualquier estado, con `motivo_rechazo` y `solicitudes_pendientes` |
| `POST /api/servicios` | Verificado | Publica; nace `pendiente`. Máximo 10 pendientes por usuario |
| `PUT /api/servicios/{id}` | Verificado, dueño | Edita; **vuelve a `pendiente`** para revisión |
| `PATCH /api/servicios/{id}/pausa` `{ "pausado": true }` | Sesión, dueño | `aprobado` ⇄ `pausado`, sin nueva revisión |
| `DELETE /api/servicios/{id}` | Sesión, dueño | Borra servicio, imágenes (también en Storage), solicitudes y reseñas. `409` si tiene solicitudes aceptadas |
| `POST /api/servicios/{id}/imagenes` (multipart, campo `imagenes`) | Verificado, dueño | 1–5 archivos JPG/PNG/WebP de hasta 5 MB (se valida el contenido real). Máximo 5 por servicio. Vuelve a `pendiente` |
| `PUT /api/servicios/{id}/imagenes/orden` `{ "imagenes": [idImg, …] }` | Sesión, dueño | Todas las imágenes en el orden deseado; la primera es la portada |
| `DELETE /api/servicios/{id}/imagenes/{idImagen}` | Sesión, dueño | Borra y reordena |

**Cuerpo de `POST`/`PUT`**
```json
{
  "titulo": "Clases de Física Mecánica",          // 5–100
  "descripcion": "Cinemática, dinámica y energía…", // 20–2000
  "id_categoria": 1,
  "precio": 25000,                                 // 1.000 – 99.999.999 COP
  "unidad_precio": "hora",                         // hora | mes | proyecto (opcional: arriendo → mes, resto → hora)
  "modalidad": "virtual",                          // presencial | virtual | mixta
  "disponibilidad": "fines_de_semana",             // entre_semana | fines_de_semana | siempre
  "contacto": "3009998888",                        // correo o teléfono, 5–150
  "direccion": null, "ubicacion_lat": null, "ubicacion_lng": null  // lat y lng van juntas
}
```

**Tarjeta del listado**
```json
{ "id_servicio": 10, "id_proveedor": 1, "titulo": "…", "descripcion": "…", "id_categoria": 1,
  "categoria": "Tutorías", "precio": 20000, "unidad_precio": "hora", "modalidad": "presencial",
  "disponibilidad": "entre_semana", "fecha_publicacion": "2026-09-01T00:00:00Z", "proveedor": "Ana",
  "universidad": "…", "avatar": null, "imagen": "https://…", "num_resenas": 1, "promedio": 4.0 }
```
La respuesta del listado es `{ servicios, pagina, por_pagina, total, total_paginas }`. `avatar` e `imagen` son `null` cuando no hay una URL real (las rutas `img/…` de la web antigua se descartan).

**Estados de un servicio**: `pendiente` (espera revisión) → `aprobado` (público) ⇄ `pausado` (lo decide el proveedor). Un admin puede dejarlo `rechazado` con `motivo_rechazo`; si el proveedor lo edita, vuelve a `pendiente`.

## Solicitudes — `/api/solicitudes`

| Método y ruta | Acceso | Qué hace |
|---|---|---|
| `POST /api/solicitudes` | Verificado | Crea la solicitud (`Pendiente`), abre o reutiliza el chat con el proveedor y le envía un mensaje del sistema y un correo. `409` si ya hay una activa para ese servicio |
| `GET /api/solicitudes/enviadas?estado=` | Sesión | Como cliente |
| `GET /api/solicitudes/recibidas?estado=` | Sesión | Como proveedor |
| `GET /api/solicitudes/{id}` | Sesión, parte | Sólo cliente o proveedor |
| `POST /api/solicitudes/{id}/aceptar` `{ "contraoferta": 35000 }` | Proveedor | `Pendiente` → `Aceptada` (contraoferta opcional) |
| `POST /api/solicitudes/{id}/rechazar` `{ "motivo": "…" }` | Proveedor | `Pendiente` → `Rechazada` |
| `POST /api/solicitudes/{id}/completar` | Proveedor | `Aceptada` → `Completada` (habilita la reseña) |
| `POST /api/solicitudes/{id}/cancelar` | Cliente | `Pendiente` o `Aceptada` → `Cancelada` |

**Cuerpo de `POST`**
```json
{ "id_servicio": 10, "descripcion": "Necesito repasar dinámica…", "presupuesto": 40000,
  "fecha_deseada": "2026-11-20", "hora_deseada": "14:30",
  "campos": { "cantidad_paginas": "4-6 páginas" } }
```
`campos` admite `cantidad_paginas`, `lenguaje`, `dias_estadia` y `fecha_inicio` (ver `solicitud_config.dart`). Cada fila de las listas incluye `rol` (`cliente`/`proveedor`), `servicio`, `cliente`, `proveedor`, `puede_calificar` e `id_calificacion`. Una acción que no corresponde al estado actual responde `409`.

Adjuntar archivos a una solicitud **aún no está disponible**: los documentos no deben ir al bucket público de imágenes; necesitan un bucket privado con URLs firmadas.

## Calificaciones — `/api/calificaciones`

| Método y ruta | Acceso | Qué hace |
|---|---|---|
| `GET /api/calificaciones/estado?id_servicio=` | Sesión | `{ puede_calificar, ya_califico, mi_calificacion }` para mostrar el formulario |
| `POST /api/calificaciones` `{ id_servicio, puntuacion, comentario }` | Verificado | Sólo con una solicitud `Completada` del usuario; una reseña por servicio |
| `PUT /api/calificaciones/{id}` `{ puntuacion, comentario }` | Sesión, autor | Edita la reseña propia |

Las reseñas de un servicio se leen en `GET /api/servicios/{id}`.

## Moderación (panel admin) — `/api/admin/servicios`

| Método y ruta | Qué hace |
|---|---|
| `GET /api/admin/servicios?estado=pendiente&busqueda=` | Pendientes primero (los más antiguos arriba). Acepta también `publicados`/`pendientes` |
| `PATCH /api/admin/servicios/{id}/aprobar` | `pendiente` → `aprobado`, avisa por correo |
| `POST /api/admin/servicios/{id}/rechazar` `{ "razon": "…" }` | `pendiente` → `rechazado` con motivo (ya no borra) |
| `PATCH /api/admin/servicios/{id}/ocultar` `{ "motivo": "…" }` | `aprobado`/`pausado` → `rechazado` con motivo |

## Pruebas

`UniserviceAPI/tests/servicios-e2e`: `node run.mjs` (requiere Docker y .NET). Levanta PostgreSQL desechable con las tablas antiguas, aplica 001 → 008, compila y prueba la API completa (107 comprobaciones). No toca Supabase ni envía correos.
