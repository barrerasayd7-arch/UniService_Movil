# Guía de defensa — UniService

> Respuestas preparadas a partir del código actual del proyecto.
> La idea es explicar de forma simple, pero con datos concretos.
> Cuando algo está incompleto, la guía lo dice: reconocer la deuda también suma.

---

## 1. Discurso general de 2 minutos

> “UniService es una plataforma de servicios universitarios. Tenemos tres partes: una app Flutter, una API en ASP.NET Core 8 y una base de datos PostgreSQL en Supabase.
>
> En Flutter separamos el proyecto por capas y por funcionalidades: `core` para tema y configuración, `data` para HTTP, sesión y repositorios, `models` para los DTO, `screens` para las pantallas y `widgets` para componentes reutilizables. No usamos Provider, Riverpod ni Bloc. El estado compartido lo manejamos con repositorios singleton y `ValueNotifier`; el estado local de cada pantalla, con `setState`.
>
> Todas las peticiones HTTP pasan por un único `ApiClient`, que agrega el JWT, maneja timeouts, multipart y traduce errores. Las pantallas nunca llaman `http` directamente: llaman a un repositorio.
>
> En el backend usamos controllers con Npgsql y SQL parametrizado. EF Core está registrado, pero no es la fuente del esquema. La base se administra con migraciones SQL numeradas y funciones como `uniservice_mobile.listar_servicios`.
>
> La seguridad se basa en JWT, BCrypt, filtros globales de autorización, rate limiting, OTP para el correo institucional y una segunda contraseña para el panel administrativo.”

---

## 2. Preguntas generales

### 2.1 “¿Cómo manejan los providers?”

**Respuesta corta:**

> “No usamos el paquete Provider. La función de proveedor de estado la cumplen los repositorios singleton de `lib/data`, que guardan el estado compartido y exponen `ValueNotifier`. Las pantallas escuchan esos notifiers o usan `setState` para lo local.”

**Si preguntan por qué:**

> “Porque el estado realmente compartido es pequeño: la sesión del usuario y un contador de cambios de servicios y solicitudes. Meter Provider o Riverpod para eso era sobreingeniería. Con singletons y `ValueNotifier` tenemos lo necesario sin una dependencia extra. El costo es que la dependencia es global y hay que cuidar los listeners.”

**Ejemplos concretos:**

- `AuthRepository.instance.usuario` es un `ValueNotifier<AuthUser?>`.
- `ServiciosRepository.cambios` y `SolicitudesRepository.cambios` avisan cuando hay que recargar listas.
- El explorador de servicios escucha `ServiciosRepository.cambios` y se recarga.
- `MisServiciosScreen` y `SolicitudesScreen` hacen lo mismo.

**Ojo con una posible confusión:** si por “providers” se refieren a **proveedores de servicio**, no hay tabla `proveedores`. Un usuario con rol 2 publica servicios y actúa como proveedor.

---

### 2.2 “¿Cómo estructuraron el proyecto?”

**Respuesta corta:**

> “Lo organizamos por capas y por feature. En Flutter: `core`, `data`, `models`, `screens` y `widgets`. En el backend: `Controllers`, `Services`, `DTOs`, `Models` y `Hubs`. La base vive aparte, en `database/migrations`.”

**Flutter:**

| Carpeta | Responsabilidad |
|---|---|
| `lib/core/` | Tema, colores, tipografías, categorías, entorno y configuración de formularios |
| `lib/data/` | `ApiClient`, sesión cifrada y repositorios |
| `lib/models/` | DTO y parseo JSON |
| `lib/screens/` | Pantallas agrupadas por flujo: login, home, perfil, publicar, detalle, solicitudes, admin |
| `lib/widgets/` | Componentes reutilizables |
| `lib/main.dart` | Arranque, rutas y guardas |

**Backend:**

> “Los controllers reciben HTTP y ejecutan la consulta; los services son utilidades de infraestructura: correo, storage, tokens, validación. No tenemos una capa repository formal.”

**Base de datos:**

> “Las migraciones están separadas del código de la API. La app no crea tablas; la API tampoco usa `dotnet ef` como fuente del esquema.”

---

### 2.3 “¿Cómo manejaron los estados?”

**Respuesta corta:**

> “Manejamos tres niveles: estado global, estado de pantalla y estado efímero de UI.”

1. **Global:** sesión y avisos de cambio.
   - `AuthRepository.usuario`
   - `ServiciosRepository.cambios`
   - `SolicitudesRepository.cambios`
   - `ApiClient.token` y `ApiClient.adminToken`

2. **De pantalla:** `StatefulWidget` + `setState`.
   - `_cargando`, `_error`, `_guardando`
   - filtros, página, búsqueda
   - listas recibidas/enviadas
   - pestaña activa

3. **Efímero:** controladores y animaciones.
   - `TextEditingController`
   - `FocusNode`
   - `AnimationController`
   - `DefaultTabController`

**Ejemplo de flujo:**

> “El usuario publica un servicio. `ServiciosRepository.crear()` hace el `POST`, incrementa `cambios` y el explorador y ‘Mis servicios’ se recargan solos.”

**Sesión:**

> “El JWT se guarda cifrado con `flutter_secure_storage`. Al arrancar, `AuthRepository.restaurar()` recupera la sesión. Si un endpoint responde 401, `ApiClient` dispara `onSesionInvalida`, se limpia la sesión y `main.dart` redirige al login.”

---

### 2.4 “¿Cómo hicieron la base de datos?”

**Respuesta corta:**

> “Es PostgreSQL en Supabase. Partimos de un esquema legado del proyecto web y lo adaptamos con migraciones SQL numeradas. Usamos el esquema `public` para las tablas y `uniservice_mobile` para funciones y control interno.”

**Migraciones principales:**

- `001`: esquema `uniservice_mobile`, tablas de bolsa/perfiles, habilidades y RLS.
- `002`: funciones de servidor para peticiones y postulaciones.
- `004`: verificación de correo institucional por OTP.
- `005`: suspensión de usuarios y auditoría administrativa.
- `007`: cierre de acceso público y activación de RLS.
- `008`: adaptación de servicios móviles: estados, unidad de precio, imágenes y solicitudes.
- `009`: sesiones válidas, seguidores y chat.
- `010`: segunda contraseña de administrador.

La ruta activa es `001 → 002 → 004 → 005 → 007 → 008 → 009 → 010`.
La `003` corresponde a una ruta Microsoft descartada y la `006` es solo datos.

**Tablas importantes:**

| Tabla | Para qué sirve |
|---|---|
| `usuarios` | Cuenta, perfil, rol y estado |
| `rol_usuarios` | Roles: 1 admin, 2 usuario |
| `categorias` | Catálogo de categorías |
| `servicios` | Servicio publicado por un usuario |
| `servicios_imagenes` | Hasta 5 imágenes por servicio |
| `solicitudes` | Contratación de un servicio |
| `calificaciones` | Reseña de un cliente |
| `chats` y `mensajes` | Conversación 1:1 |
| `seguidores` | Relación de seguimiento |
| `reportes` | Denuncias |
| `auditoria_admin` | Bitácora del panel |
| `admin_credenciales` | Segunda contraseña admin |

**Relaciones clave:**

- Un usuario tiene muchos servicios.
- Un servicio tiene hasta 5 imágenes.
- Un servicio tiene muchas solicitudes.
- Una solicitud tiene un cliente y un proveedor.
- Un cliente solo puede tener una solicitud activa por servicio.
- Un cliente solo puede calificar una vez por servicio.
- Un chat es único por pareja de usuarios.

**Reglas importantes:**

- `servicios.estado`: `pendiente`, `aprobado`, `rechazado`, `pausado`.
- `solicitudes.estado`: `Pendiente`, `Aceptada`, `Rechazada`, `Completada`, `Cancelada`.
- Hay checks, FKs, índices únicos parciales y transacciones.
- No hay enums nativos; los estados son `varchar` con `CHECK`.

**Funciones SQL:**

- `uniservice_mobile.listar_servicios`: catálogo público, búsqueda sin tildes, filtros, promedio de reseñas y portada.
- `uniservice_mobile.normalizar`: quita tildes y pasa a minúsculas.
- `uniservice_mobile.exigir_correo_verificado`: valida correo institucional verificado.
- Funciones de bolsa y postulaciones, aunque la app móvil actual no use ese módulo.

**Sobre RLS:**

> “RLS está activado como cierre de seguridad, pero no hay políticas. La API entra como propietario de la base, así que la autorización real la hacen el JWT y los controllers. Si quisiéramos que Flutter hablara directo con Supabase, tendríamos que crear políticas.”

---

### 2.5 “¿Dónde consumen la API o hacen consultas?”

**Respuesta corta:**

> “En Flutter todo pasa por `ApiClient` y los repositorios. En el backend, los controllers consultan PostgreSQL con Npgsql y SQL parametrizado.”

**Flujo completo:**

```text
Pantalla Flutter
  → Repositorio
    → ApiClient
      → HTTP /api/...
        → Controller ASP.NET
          → Npgsql / función SQL
            → PostgreSQL
```

**Regla importante:**

> “Las pantallas no tienen `http` ni SQL. El único que importa `package:http` es `ApiClient`. Las consultas viven en los controllers y en las funciones SQL.”

**Ejemplo de catálogo:**

```text
ExploradorServicios
  → ServiciosRepository.listar()
    → GET /api/servicios?pagina=1&busqueda=...
      → ServiciosController
        → uniservice_mobile.listar_servicios(...)
```

**URL de la API:**

> “Se configura con `--dart-define=API_URL`. Por defecto usa `10.0.2.2:5165` en emulador Android y `localhost:5165` en el resto.”

---

## 3. Preguntas específicas de la app

### 3.1 “¿Cómo funciona el login y el registro?”

> “El registro usa el correo institucional `@unicesar.edu.co`. Se envía un código OTP de 6 dígitos, se verifica y se obtiene un token temporal. Con ese token se crea la cuenta. El login valida correo y contraseña con BCrypt, devuelve un JWT y la app lo guarda cifrado.”

- OTP: 6 dígitos, 10 minutos, un solo uso, máximo 5 intentos y reenvío cada 60 segundos.
- Token de verificación: 15 minutos.
- JWT normal: 1 día.
- JWT admin: 8 horas.
- Logout y cambio de contraseña revocan sesiones anteriores.

---

### 3.2 “¿Cómo buscan, filtran y paginan servicios?”

> “La búsqueda y los filtros se resuelven en el servidor, no en Flutter. El explorador pide 12 servicios por página. La búsqueda tiene un debounce de 350 ms. Si llegan respuestas viejas, se descartan con una guardia de petición.”

- Endpoint: `GET /api/servicios`.
- Filtros: categoría, texto y orden.
- Búsqueda sin tildes: función `normalizar`.
- Paginación: `pagina`, `por_pagina`, total.
- Destacados: hasta 5 servicios con reseñas.

---

### 3.3 “¿Cómo publican un servicio?”

> “El formulario crea o edita según el argumento de la ruta. Se validan los datos, se envía el servicio y luego se sincronizan las imágenes. El servicio queda `pendiente` hasta que un admin lo apruebe.”

- Máximo 5 fotos.
- Máximo 5 MB por foto.
- Las fotos se reducen a 1920 px antes de subirlas.
- Se suben como multipart.
- La primera imagen es la portada.
- Si falla la subida después de crear, queda en modo edición para reintentar sin duplicar.

---

### 3.4 “¿Cómo funcionan las solicitudes?”

> “El cliente crea una solicitud sobre un servicio. El backend valida que no exista otra solicitud activa para ese cliente y servicio, y crea un chat con un mensaje de sistema que resume la solicitud. Luego el proveedor puede aceptar, rechazar o completar; el cliente puede cancelar.”

- Estados: `Pendiente → Aceptada → Completada`.
- También: `Pendiente → Rechazada`.
- Cancelación desde `Pendiente` o `Aceptada`.
- Aceptar permite contraoferta.
- Rechazar exige motivo.
- Cada cambio recarga las listas.

---

### 3.5 “¿Cómo funcionan las calificaciones?”

> “Se califica una sola vez por cliente y servicio. La API valida que la solicitud esté completada. Si ya existe, se puede editar. El promedio se calcula en SQL y se muestra en el detalle y en el catálogo.”

- `UNIQUE (id_cliente, id_servicio)`.
- Puntuación de 1 a 5.
- Comentario máximo 1000 caracteres.
- Se puede editar, pero no crear varias reseñas.

---

### 3.6 “¿Cómo funciona el perfil?”

> “Tenemos perfil propio y perfil público. El propio trae correo y teléfono; el público oculta datos de contacto. Se puede seguir/dejar de seguir, cambiar avatar, compartir y reportar.”

- `GET /api/perfil/me`.
- `GET /api/perfil/{id}`.
- `PUT /api/perfil/me`.
- Avatar: JPG/PNG/WebP, máximo 2 MB, sin EXIF/GPS.
- Seguidores: máximo 50 en la vista.
- Reportar usuario sí está implementado.

---

### 3.7 “¿Cómo protegen el panel de administración?”

> “No basta con tener rol admin. Se necesita una segunda contraseña administrativa. Al verificarla, el backend devuelve un token de elevación que la app manda en `X-Admin-Elevacion`. Ese token solo se envía a rutas `/api/admin/*` y dura aproximadamente una hora.”

- JWT identifica al usuario.
- `id_rol = 1` indica admin.
- `admin_credenciales` guarda la segunda contraseña con BCrypt.
- Hay bloqueo tras varios intentos.
- El token de elevación vive en memoria, no en almacenamiento.
- Cambiar la contraseña admin invalida las elevaciones anteriores.

---

### 3.8 “¿Qué pasa con el chat y las notificaciones?”

**Respuesta honesta:**

> “El backend tiene chat y SignalR, y al crear una solicitud se crea el chat con un mensaje de sistema. Pero la app todavía no tiene pantalla de chat ni repositorio de mensajes. Las notificaciones actuales son simuladas en memoria; no hay tabla de notificaciones ni push.”

Esto es mejor decirlo así: “está la base, falta la interfaz” y no “no existe nada”.

---

### 3.9 “¿Dónde se manejan los errores?”

> “El `ApiClient` convierte timeouts, falta de red y errores HTTP en `ApiException` con mensajes en español. El backend tiene un handler global y respuestas uniformes para validación. En la UI mostramos snackbars, estados de error y botones de reintento.”

- 400: datos inválidos.
- 401: sesión vencida.
- 403: sin permiso, suspendido, sin correo verificado o sin elevación admin.
- 404: no existe o no es tuyo.
- 409: duplicado o estado incompatible.
- 429: demasiados intentos.
- 503: servicio no configurado.

---

### 3.10 “¿Cómo prueban el proyecto?”

> “En Flutter tenemos pruebas unitarias y de widgets con un `MockClient`; no necesitan API real. En backend tenemos una suite e2e en Node que levanta PostgreSQL en Docker, compila la API y prueba más de 200 casos. También hay pruebas de migraciones con PGlite.”

- Flutter: 25 pruebas.
- Backend: `e2e.mjs` y `perfil.mjs`.
- DB: `verify.mjs` y `servicios.mjs`.
- No hay CI; se ejecuta manualmente.

---

### 3.11 “¿Cómo manejan la seguridad?”

> “La identidad sale del JWT, no del cuerpo. Las contraseñas se guardan con BCrypt. Hay un filtro global que exige autenticación y otro que bloquea cuentas suspendidas. Además hay rate limiting, validación de entrada, OTP institucional, tokens de sesión revocables y una segunda contraseña para admin.”

- El backend ignora `id_usuario`, `id_proveedor` o `id_rol` enviados en el body.
- Los recursos ajenos responden 404 para no revelar su existencia.
- Los errores de validación no exponen detalles internos en producción.
- Los secretos viven en `.env`, fuera del repositorio.
- Los archivos se validan por bytes, no por extensión.

---

## 4. Preguntas difíciles y cómo responderlas

### “¿Por qué no usaron Provider?”

> “Porque el estado compartido era pequeño y no queríamos agregar un framework solo por dos o tres valores globales. Usamos singletons con `ValueNotifier`, que nos da reactividad sin dependencia. Si la app creciera mucho, migraríamos a Riverpod o Bloc.”

### “¿Por qué usan SQL crudo y no EF Core?”

> “Porque el esquema venía de un proyecto web con funciones SQL y consultas complejas. EF Core no modelaba esa realidad y nos obligaba a duplicar el esquema. Preferimos Npgsql con SQL parametrizado para tener control y compatibilidad. EF Core quedó registrado, pero no es la fuente del esquema.”

### “¿No es peligroso SQL crudo?”

> “No, porque usamos parámetros, no concatenamos datos del usuario. Los únicos nombres de columna o tabla que se interpolan son internos y están controlados. Además, hay validación de entrada y pruebas e2e.”

### “¿Cómo evitan que un usuario modifique datos de otro?”

> “La identidad y la propiedad salen del JWT, no del cuerpo. Si el cliente manda `id_usuario` o `id_proveedor`, se ignora. En los recursos ajenos devolvemos 404 para no revelar que existen. Las operaciones críticas usan transacciones y `FOR UPDATE`.”

### “¿Cómo manejan concurrencia?”

> “Usamos transacciones, bloqueos `FOR UPDATE` y un índice único parcial para evitar dos solicitudes activas iguales. Para OTP y login Microsoft usamos `pg_advisory_xact_lock`. La limitación es que las pruebas de PGlite son de una sola conexión; la concurrencia real se debe probar en PostgreSQL.”

### “¿Qué pasa si se cae la API?”

> “El `ApiClient` tiene timeout de 15 segundos y las subidas de 90. Si no hay respuesta, lanza `ApiException` con estado 0 y un mensaje de conexión. Las pantallas muestran error y botón de reintentar.”

### “¿Qué falta o qué mejorarían?”

> “Lo principal es cerrar chat y notificaciones en la app, persistir ubicación al publicar/editar, implementar reportes de servicio, agregar la vista admin de solicitudes y CRUD de categorías, y sumar CI. También mejoraría la separación del backend con repositorios y limpiaría metadatos de imágenes de servicios, que hoy solo se limpian en avatares y evidencias.”

### “¿Qué debilidad tiene la base?”

> “El esquema original es legado y no está completo en el repo; lo que tenemos son las migraciones que lo adaptan. RLS está activo pero sin políticas, porque la API entra como owner. Y no hay tabla de notificaciones ni historial general de solicitudes; el estado se guarda en la fila.”

---

## 5. Chuleta para memorizar

- **Estado:** sin Provider; repositorios singleton + `ValueNotifier` + `setState`.
- **HTTP:** todo por `ApiClient`; pantallas → repositorios → API.
- **Backend:** controllers + Npgsql; EF Core registrado pero sin uso.
- **DB:** PostgreSQL/Supabase; migraciones SQL 001–010; `public` + `uniservice_mobile`.
- **Catálogo:** `GET /api/servicios` → `listar_servicios`; búsqueda sin tildes.
- **Auth:** JWT + BCrypt + OTP institucional + `sesiones_validas_desde`.
- **Admin:** rol 1 + segunda contraseña + `X-Admin-Elevacion`.
- **Solicitudes:** una activa por cliente/servicio; chat automático; estados con checks.
- **Imágenes:** 5 máximo, 5 MB, tipo por bytes, Supabase Storage.
- **Tests:** 25 Flutter + 200+ e2e + PGlite; sin CI.
- **Deuda:** chat UI, notificaciones reales, ubicación, reporte de servicio, admin solicitudes, categorías CRUD.

---

## 6. Limitaciones que conviene reconocer

- Chat: backend y SignalR existen, pero falta la pantalla y el repositorio de mensajes en Flutter.
- Notificaciones: son simuladas en memoria; no hay tabla ni push.
- Ubicación: el formulario no tiene selector de mapa y editar puede borrar coordenadas.
- Reportar servicio: el botón es un stub; reportar usuario sí funciona.
- Admin: el backend expone solicitudes, pero no hay pantalla; categorías es solo lectura.
- Navegación: `/home`, `/perfil` y `/login` no tienen todas las guardas.
- Archivos: las imágenes de servicios no pierden metadatos; avatares y evidencias sí.
- Infraestructura: no hay CI y las migraciones se ejecutan manualmente.

---

## 7. Archivos clave para ubicarse

- `UniService_Movil/lib/main.dart`: rutas, guardas y arranque.
- `UniService_Movil/lib/data/api_client.dart`: HTTP, JWT, errores y multipart.
- `UniService_Movil/lib/data/*_repository.dart`: endpoints por dominio.
- `UniService_Movil/lib/models/`: DTO y parseo JSON.
- `UniService_Movil/lib/screens/`: pantallas por flujo.
- `UniService_Movil/lib/widgets/explorador_servicios.dart`: catálogo, filtros y paginación.
- `UniserviceAPI/UniserviceAPI/Program.cs`: DI, JWT, CORS, rate limit y filtros globales.
- `UniserviceAPI/UniserviceAPI/Controllers/`: endpoints y consultas Npgsql.
- `UniserviceAPI/UniserviceAPI/Services/`: correo, storage, tokens y validación.
- `UniService_Movil/database/migrations/`: esquema y funciones SQL.
- `UniService_Movil/database/docs/`: contratos de API y base de datos.
- `UniService_Movil/docs/ARQUITECTURA_LIB.md`: mapa detallado de `lib/`.

---

## 8. Consejo final para responder

No intentes defender que todo está terminado. La mejor respuesta es:

> “Esto ya funciona; esto está implementado en backend pero falta la UI; esto lo haríamos como siguiente iteración.”

Eso transmite control del proyecto y madurez técnica.
