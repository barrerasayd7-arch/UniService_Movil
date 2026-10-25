# Arquitectura de `lib/` — app UniService

Documento de referencia del cliente Flutter. Cubre **los 74 archivos `.dart`** de `lib/`
(**20.689 líneas físicas**), su responsabilidad, las rutas y los flujos principales, y una
lista priorizada de funciones faltantes, incompletas o con contratos desalineados.

- App: `UniService_Movil/UniService_Movil/` (`app_uniservice`).
- API: ASP.NET Core 8 en `UniService_Movil/UniserviceAPI/UniserviceAPI/`.
- Base de datos: PostgreSQL/Supabase; la API usa SQL y funciones `uniservice_mobile`.
- Fecha de este relevamiento: 2026-10-25.

> Convención: `LOC` = líneas físicas del archivo. Las referencias `archivo:línea`
> apuntan al código actual, no a documentación externa.

---

## 1. Resumen ejecutivo

La app es un cliente Flutter responsive (móvil, web y escritorio) con tema oscuro.
No usa provider, riverpod, bloc ni get_it: el estado global se concentra en
**singletons + `ValueNotifier`**, y cada pantalla maneja su estado con `setState`.

Capas:

1. **Entrada y rutas**: `lib/main.dart`.
2. **Infraestructura HTTP/sesión**: `lib/data/api_client.dart`,
   `auth_repository.dart`, `session_store.dart`.
3. **Repositorios de dominio**: servicios, solicitudes, perfil y admin.
4. **Modelos/DTO**: `lib/models/`.
5. **Pantallas por feature**: `home`, `home_guest`, `login`, `profile`,
   `publicar`, `service_detail`, `solicitudes`, `mis_servicios`, `admin`.
6. **Widgets compartidos**: `lib/widgets/` (explorador, tarjetas, fondos animados,
   botones, estrellas, etc.).

La app ya cubre los flujos principales de autenticación, catálogo, publicación,
solicitudes, reseñas, perfil y moderación administrativa. Los huecos más importantes
son **chat**, **notificaciones reales**, **coordenadas de ubicación** y algunos
detalles de navegación/contrato.

---

## 2. Arranque y composición

1. `main()` crea/restaura la sesión desde almacenamiento seguro.
2. `AuthRepository.onSesionCerrada` se conecta a `navigatorKey`: si la API invalida
   el token, vuelve a `/login` y muestra el motivo.
3. `runApp` arranca en `/home` si hay sesión o en `/home-guest` si no.
4. `UniServiceApp` define **todas** las rutas nombradas en `main.dart`.
5. Las pantallas componen widgets de su carpeta y llaman a los repositorios
   singleton; no usan `http` directamente.
6. Los repositorios notifican cambios con `ValueNotifier` para que las listas se
   recarguen (`ServiciosRepository.cambios`, `SolicitudesRepository.cambios`).

---

## 3. Estado global y navegación

### 3.1 Estado global

| Fuente | Qué guarda | Quién lo usa |
|---|---|---|
| `AuthRepository.usuario` | `AuthUser?` de la sesión | home, navbar, perfil, guardas de admin |
| `AuthRepository.haySesion` | derivado de `usuario.value != null` | `_conSesion` |
| `AdminRepository._vence` / `ApiClient.adminToken` | elevación temporal del panel | rutas `/admin/*` |
| `ApiClient.onSesionInvalida` | callback ante 401/403 de sesión | `main.dart` |
| `ServiciosRepository.cambios` | contador de altas/ediciones/borrados | explorador, mis servicios |
| `SolicitudesRepository.cambios` | contador de solicitudes/estados | solicitudes, detalle |

El token JWT y el token de elevación son distintos:

- JWT: sesión normal; lo envía `ApiClient` en `Authorization`.
- `X-Admin-Elevacion`: sólo se agrega a rutas que empiezan con `/api/admin/`
  (`api_client.dart:92`). Vive en memoria y caduca.

### 3.2 Rutas (`main.dart`)

| Ruta | Pantalla | Protección |
|---|---|---|
| `/login` | `LoginScreen` | pública; **no redirige** si ya hay sesión |
| `/home-guest` | `HomeGuestScreen` | pública |
| `/home` | `HomeScreen` | **sin guarda de ruta** |
| `/perfil` | `ProfileScreen` (propio) | **sin guarda de ruta** |
| `/servicio` | `DetailScreen` | pública; acepta `Servicio` o `int` |
| `/perfil-externo` | `ProfileScreen(externo: true)` | pública, por diseño |
| `/publicar` | `PublicarScreen` | `_conSesion` |
| `/mis-servicios` | `MisServiciosScreen` | `_conSesion` |
| `/solicitudes` | `SolicitudesScreen` | `_conSesion`; argumento `1` = enviadas |
| `/admin` | `AdminPanelScreen` o `AdminAccesoScreen` | sesión + admin + elevación |
| `/admin/usuarios` | `AdminUsuariosScreen` | `_conPanel` |
| `/admin/servicios` | `AdminServiciosScreen` | `_conPanel` |
| `/admin/pendientes` | `AdminServiciosScreen(soloPendientes: true)` | `_conPanel` |
| `/admin/reportes` | `AdminReportesScreen` | `_conPanel` |
| `/admin/categorias` | `AdminCategoriasScreen` | `_conPanel` |
| `/admin/actividad` | `AdminActividadScreen` | `_conPanel` |

Guardas:

- `_conSesion` (`main.dart:134-135`) devuelve `LoginScreen` si no hay sesión.
- `_conPanel` (`main.dart:137-143`) exige además `usuario.esAdmin` y
  `AdminRepository.dentroDelPanel`.
- `/admin` (`main.dart:111-117`) si no es admin manda a `HomeScreen`; si es admin
  pero no tiene elevación, muestra `AdminAccesoScreen`.

**Deuda de navegación:** `/home`, `/perfil` y `/login` no tienen guarda de ruta.
La protección efectiva de `/perfil` depende del 401 de la API, y `/home` puede
renderizarse sin sesión (saludo “Usuario”, acciones que fallarán). El arranque normal
mitiga esto, pero un deep link o una navegación manual no.

---

## 4. Inventario completo de `lib/`

### 4.1 `lib/core/` — tema, configuración y catálogos fijos

| Archivo | LOC | Función |
|---|---:|---|
| `core/app_colors.dart` | 56 | Paleta del tema oscuro, alias de opacidad `a()`, colores de admin y `Breakpoints` responsive. |
| `core/app_text.dart` | 45 | Tipografías Poppins (cuerpo) y DM Serif Display (títulos) vía `google_fonts`. |
| `core/categorias.dart` | 181 | Catálogo fijo de 7 categorías, chips, iconos/colores, normalización y etiquetas de modalidad/disponibilidad. |
| `core/env.dart` | 23 | `Env.apiUrl`: `--dart-define=API_URL`, `10.0.2.2` en emulador Android y `localhost` en el resto. |
| `core/solicitud_config.dart` | 108 | Configuración de campos dinámicos del formulario de solicitud según categoría (`TipoCampo`). |

### 4.2 `lib/data/` — HTTP, sesión y repositorios

| Archivo | LOC | Función |
|---|---:|---|
| `data/admin_repository.dart` | 171 | Elevación de admin en memoria; dashboard, usuarios, servicios, reportes y auditoría. |
| `data/api_client.dart` | 160 | Cliente HTTP JSON/multipart, JWT, `X-Admin-Elevacion`, timeouts, `ApiException` y manejo de 401. |
| `data/auth_repository.dart` | 159 | Código institucional, registro, login, restablecimiento, cambio de contraseña, logout y restauración de sesión. |
| `data/perfil_repository.dart` | 67 | Perfil propio/público, avatar, seguir/dejar de seguir, inicio de chat y reportes. |
| `data/servicios_repository.dart` | 136 | Listado público, detalle, CRUD de servicios propios e imágenes; define `DatosServicio`. |
| `data/session_store.dart` | 62 | Persistencia cifrada del token y del usuario con `flutter_secure_storage`. |
| `data/solicitudes_repository.dart` | 92 | Crear/listar solicitudes, transiciones aceptar/rechazar/completar/cancelar y reseñas. |

### 4.3 `lib/main.dart`

| Archivo | LOC | Función |
|---|---:|---|
| `main.dart` | 144 | Arranque, restauración de sesión, `MaterialApp`, rutas, guardas y reacción a sesión inválida. |

### 4.4 `lib/models/` — DTOs y parseo JSON

| Archivo | LOC | Función |
|---|---:|---|
| `models/admin_models.dart` | 209 | `PaginaAdmin<T>` y DTOs de usuario, servicio, reporte y auditoría del panel. |
| `models/auth_user.dart` | 30 | Identidad mínima de la sesión (`id`, nombre, correo, rol, `esAdmin`). |
| `models/mi_servicio.dart` | 53 | Fila de “mis servicios”: estado, precio, categoría, portada, reseñas y solicitudes pendientes. |
| `models/servicio.dart` | 98 | Tarjeta pública de servicio y página paginada (`PaginaServicios`). |
| `models/servicio_detalle.dart` | 184 | Detalle: servicio, proveedor, contacto, dirección, lat/lng, imágenes y reseñas. |
| `models/solicitud.dart` | 139 | Solicitud cliente/proveedor, estados, campos dinámicos y estado de calificación. |
| `models/usuario.dart` | 141 | Perfil completo/público, `PersonaResumen` y formateo de números. |

### 4.5 `lib/screens/admin/` — panel de administración

| Archivo | LOC | Función |
|---|---:|---|
| `screens/admin/admin_acceso_screen.dart` | 519 | Puerta del panel: contraseña de admin, creación/restablecimiento con código y bloqueo temporal. |
| `screens/admin/admin_actividad_screen.dart` | 135 | Bitácora paginada de acciones administrativas, con filtro por entidad. |
| `screens/admin/admin_categorias_screen.dart` | 201 | Categorías fijas con conteo de servicios publicados; **sólo lectura**. |
| `screens/admin/admin_comun.dart` | 670 | Piezas compartidas: `AdminScaffold`, filtros, lista paginada, mensajes, visor de imágenes y acciones con elevación. |
| `screens/admin/admin_drawer.dart` | 120 | Menú lateral del panel y cierre de sesión administrativa. |
| `screens/admin/admin_panel_screen.dart` | 263 | Dashboard con métricas de `/api/admin/dashboard` y accesos rápidos. |
| `screens/admin/admin_reportes_screen.dart` | 429 | Reportes: filtro por estado, detalle y actualización de estado/notas. |
| `screens/admin/admin_servicios_screen.dart` | 604 | Moderación: listar/filtrar, ver detalle, aprobar, rechazar y ocultar servicios. |
| `screens/admin/admin_usuarios_screen.dart` | 269 | Usuarios: búsqueda, filtro activos/suspendidos, suspender con motivo y reactivar. |
| `screens/admin/admin_widgets.dart` | 329 | Aviso de modo admin, insignia, confirmaciones y diálogos de motivo. |

### 4.6 `lib/screens/home/` — inicio autenticado

| Archivo | LOC | Función |
|---|---:|---|
| `screens/home/botones_flotantes.dart` | 285 | Botón flotante de chat y campana de notificaciones; **datos de ejemplo**. |
| `screens/home/footer_home.dart` | 189 | Pie de página del usuario autenticado; enlaces de soporte/cuenta en gran parte stub. |
| `screens/home/home_screen.dart` | 229 | Compone navbar, hero, buscador, recientes, destacados, CTA de publicación, footer y botones flotantes. |
| `screens/home/navbar_home.dart` | 409 | Barra superior y menú móvil del usuario autenticado. |
| `screens/home/tarjeta_publicar.dart` | 256 | Tarjeta CTA de la sección “Publicar” con fondo de circuito. |

### 4.7 `lib/screens/home_guest/` — inicio público

| Archivo | LOC | Función |
|---|---:|---|
| `screens/home_guest/footer_invitado.dart` | 176 | Pie de página para invitados. |
| `screens/home_guest/hero_presentacion.dart` | 164 | Hero público con tesseract, iconos flotantes, título, descripción y CTAs. |
| `screens/home_guest/home_guest_screen.dart` | 139 | Landing pública: navbar, hero, explorador y footer. |
| `screens/home_guest/navbar_invitado.dart` | 280 | Barra superior y menú móvil para invitados. |

### 4.8 `lib/screens/login/` — autenticación

| Archivo | LOC | Función |
|---|---:|---|
| `screens/login/auth_lateral.dart` | 492 | Panel de marca del login: logo, descripción, chips, iconos, orbes y destellos. |
| `screens/login/auth_widgets.dart` | 469 | Campos, tabs, botones, avisos y validaciones compartidas de autenticación. |
| `screens/login/login_form.dart` | 153 | Pestaña “Iniciar sesión”; llama a `POST /api/auth/login`. |
| `screens/login/login_screen.dart` | 206 | Contenedor responsive del login/registro con dos pestañas. |
| `screens/login/modal_codigo.dart` | 345 | Modal de código de 6 dígitos con celdas y pegado/autocompletado. |
| `screens/login/recuperar_password.dart` | 187 | Hoja de restablecimiento: correo → código → contraseña nueva. |
| `screens/login/register_form.dart` | 348 | Registro en dos pasos: código institucional y datos personales. |

### 4.9 `lib/screens/mis_servicios/`

| Archivo | LOC | Función |
|---|---:|---|
| `screens/mis_servicios/mis_servicios_screen.dart` | 544 | Servicios propios en cualquier estado; editar, pausar/reanudar, eliminar y ver detalle. |

### 4.10 `lib/screens/profile/` — perfil propio y público

| Archivo | LOC | Función |
|---|---:|---|
| `screens/profile/navbar_perfil.dart` | 219 | Barra y menú móvil del perfil; enlaces a inicio, publicar, servicios, solicitudes, soporte y logout. |
| `screens/profile/profile_background.dart` | 235 | Fondo decorativo del perfil: imagen tenue, glows, anillos, partículas y líneas. |
| `screens/profile/profile_modals.dart` | 885 | Modales de edición, avatar, seguidores/siguiendo y reporte de usuario. |
| `screens/profile/profile_screen.dart` | 888 | Perfil propio o público: datos, estadísticas, seguir, compartir, chatear (stub) y reportar. |
| `screens/profile/profile_widgets.dart` | 422 | Animaciones de entrada, estadísticas, filas de información y menús del perfil. |

### 4.11 `lib/screens/publicar/`

| Archivo | LOC | Función |
|---|---:|---|
| `screens/publicar/publicar_screen.dart` | 1023 | Formulario multipaso para crear/editar servicio, validar, elegir/ordenar fotos y guardar. |

### 4.12 `lib/screens/service_detail/` — detalle y solicitud

| Archivo | LOC | Función |
|---|---:|---|
| `screens/service_detail/detail_screen.dart` | 923 | Orquesta el detalle: carga, contacto, mapa, solicitud, reseña, acciones del dueño, reporte/chat stub. |
| `screens/service_detail/detail_widgets.dart` | 282 | Tarjetas de sección, filas de información y botones del detalle. |
| `screens/service_detail/form_calificacion.dart` | 287 | Crear/editar reseña según `GET /api/calificaciones/estado`. |
| `screens/service_detail/form_solicitud.dart` | 636 | Formulario de solicitud dependiente de categoría; muestra solicitud activa y permite cancelarla. |
| `screens/service_detail/galeria_servicio.dart` | 212 | Galería principal, miniaturas y visor de imágenes. |
| `screens/service_detail/navbar_servicio.dart` | 209 | Barra y menú móvil del detalle; distingue invitado y sesión. |
| `screens/service_detail/proveedor_card.dart` | 299 | Tarjeta del proveedor y botones de contacto (Gmail/WhatsApp/mensaje). |
| `screens/service_detail/skeleton_servicio.dart` | 71 | Esqueleto de carga con brillo animado. |

### 4.13 `lib/screens/solicitudes/`

| Archivo | LOC | Función |
|---|---:|---|
| `screens/solicitudes/solicitudes_screen.dart` | 759 | Pestañas recibidas/enviadas; aceptar con contraoferta, rechazar con motivo, completar y cancelar. |

### 4.14 `lib/widgets/` — componentes compartidos

| Archivo | LOC | Función |
|---|---:|---|
| `widgets/animacion_ambiental.dart` | 24 | Envuelve animaciones en `TickerMode`; las desactiva en móvil o con “reducir movimiento”. |
| `widgets/app_buttons.dart` | 127 | Botones CTA (`BtnVerde`) y de borde (`BtnBorde`) con hover. |
| `widgets/avatar_respaldo.dart` | 23 | `errorBuilder` de avatares: icono de persona si la imagen falla. |
| `widgets/cosmos_background.dart` | 373 | Fondo cósmico animado con anillos 3D, rayos, órbitas y estrellas. |
| `widgets/explorador_servicios.dart` | 744 | Buscador, chips, orden, fila de destacados, resultados paginados y “Ver más”. |
| `widgets/floating_icons.dart` | 169 | Iconos que caen girando y círculos de brillo pulsantes. |
| `widgets/google_g_logo.dart` | 54 | Logo “G” de Google dibujado con arcos; **sin referencias externas**. |
| `widgets/section_backgrounds.dart` | 186 | Fondos por sección: grilla, circuito y estrellas; sólo `circuito` se usa. |
| `widgets/section_label.dart` | 96 | Chip de etiqueta de sección y palabra acentuada con subrayado. |
| `widgets/star_rating.dart` | 88 | Cinco estrellas con relleno parcial. |
| `widgets/tarjeta_servicio.dart` | 432 | Tarjeta de servicio: portada, categoría, precio, título, proveedor y rating. |
| `widgets/tesseract_background.dart` | 355 | Hipercubo 4D animado con cubo interior, infinito y partículas. |

---

## 5. Flujos principales

### 5.1 Registro e inicio de sesión

1. El usuario ingresa su correo institucional.
2. `AuthRepository.enviarCodigo` pide `POST /api/auth/institutional-email/send-code`.
3. `modal_codigo` valida el código con `verify-code` y obtiene un token de 15 min.
4. `register_form` envía los datos + token a `POST /api/auth/register`.
5. `login_form` usa `POST /api/auth/login`.
6. `_abrirSesion` guarda token/usuario en `SessionStore`, configura `ApiClient.token` y
   actualiza `usuario`.
7. Al abrir la app, `restaurar()` recupera la sesión.
8. Un 401/403 de sesión dispara `onSesionInvalida`: limpia todo y vuelve a `/login`.

### 5.2 Catálogo y búsqueda

- `ExploradorServicios` llama a `GET /api/servicios` con búsqueda, categoría, orden y página.
- Sin filtros, pide aparte los mejor calificados (`rating-mayor`) y muestra hasta 5 con reseñas.
- La paginación usa `_peticion` para descartar respuestas viejas y desactiva “Ver más”
  mientras carga (`explorador_servicios.dart:98-130, 566-568`).
- Se recarga cuando `ServiciosRepository.cambios` aumenta.

### 5.3 Publicar o editar un servicio

1. `/publicar` sin argumento crea; con `int` edita.
2. `_cargar`/`_rellenar` traen el detalle si es edición.
3. `_guardar` valida y envía `DatosServicio.toJson()` a `POST` o `PUT`.
4. Luego sincroniza fotos (`subirImagenes`, orden, eliminación).
5. El servicio queda `pendiente` hasta aprobación administrativa.

### 5.4 Solicitar un servicio

1. El detalle muestra `FormSolicitud` si hay sesión.
2. La configuración de campos depende de la categoría (`solicitud_config.dart`).
3. `SolicitudesRepository.crear` envía `POST /api/solicitudes`.
4. El backend crea/reutiliza el chat; la app **no** tiene pantalla para abrirlo.
5. Si ya hay una solicitud activa, el formulario se reemplaza por su estado y opción de cancelar.

### 5.5 Gestionar solicitudes

- `SolicitudesScreen` carga recibidas y enviadas en paralelo.
- Acciones: aceptar (con contraoferta), rechazar (con motivo), completar y cancelar.
- Cada transición notifica `SolicitudesRepository.cambios`.

### 5.6 Calificar

- `FormCalificacion` consulta `GET /api/calificaciones/estado`.
- Si puede calificar, crea (`POST /api/calificaciones`); si ya calificó, edita (`PUT`).
- El detalle se recarga con `onGuardada`.

### 5.7 Perfil, seguir y reportar

- Perfil propio: `GET/PUT /api/perfil/me`, avatar y cambio de contraseña.
- Perfil público: `GET /api/perfil/{id}`, seguir/dejar de seguir, compartir y reportar.
- Reporte de usuario: `POST /api/reportes` con `id_usuario_reportado`.
- El botón “Chatear” es un stub.

### 5.8 Administración

1. `/admin` exige sesión, rol admin y elevación vigente.
2. `AdminAccesoScreen` valida/crea la contraseña de administrador.
3. El token de elevación se guarda sólo en memoria (`ApiClient.adminToken`).
4. `AdminScaffold` detecta `requiere_elevacion` y regresa a la puerta de acceso.
5. Dashboard, usuarios, servicios, reportes, categorías y auditoría consumen `/api/admin/*`.

---

## 6. Funciones faltantes o incompletas

Prioridad por impacto funcional. No son `TODO` en el código: son stubs, flujos
silenciosos, datos no persistidos o contratos que no coinciden.

### P0 — flujos anunciados que no existen o pierden datos

| # | Función | Estado actual | Evidencia | Impacto |
|---:|---|---|---|---|
| 1 | **Chat cliente/proveedor** | El backend tiene `ChatController` completo y `PerfilRepository.iniciarChat`, pero no hay modelo, repositorio de mensajes, pantalla ni ruta. `POST /api/solicitudes` ya devuelve `id_chat`, pero `SolicitudesRepository.crear` lo descarta. Los botones muestran “próxima vista”. | `perfil_repository.dart:48-52`; `solicitudes_repository.dart:20-37`; `SolicitudesController.cs:101-116`; `detail_screen.dart:521`; `profile_screen.dart:294`; `home_screen.dart:223` | El usuario no puede leer ni enviar mensajes, aunque la solicitud ya cree el chat. |
| 2 | **Notificaciones reales** | `BotonesFlotantes` usa una lista `_notifs` hardcodeada; “vaciar” y “leer” sólo cambian estado local. No hay endpoint/repositorio de notificaciones. | `botones_flotantes.dart:13-15, 28-33, 65-70` | Campana y badge son decorativos; no reflejan solicitudes, reseñas ni aprobaciones. |
| 3 | **Ubicación del servicio** | `DatosServicio` no tiene `ubicacion_lat/lng`; el formulario no tiene selector de mapa; `_rellenar` ignora las coordenadas al editar. La API sí las acepta y en el `PUT` las escribe como `NULL` si faltan. | `servicios_repository.dart:10-43`; `publicar_screen.dart:104-123, 279-289`; `ServiciosController.cs:256-280` | No se puede publicar con mapa y **editar un servicio borra su ubicación**. El detalle sí sabe abrir el mapa si hay lat/lng. |
| 4 | **Reportar un servicio** | El botón junto al título sólo muestra un aviso; el reporte de usuario sí funciona. El backend y `PerfilRepository.reportar` ya aceptan `id_servicio`. | `detail_screen.dart:476-478`; `perfil_repository.dart:54-66`; `ReportesController.cs:37-40` | No se pueden reportar fraudes/contenido de un servicio desde su detalle. |
| 5 | **Assets de perfil** | Faltan `assets/img/default-avatar.png` y `assets/img/fondo1.jpg`. Hay `errorBuilder`, así que no rompen el build, pero desaparecen el avatar por defecto y la textura de fondo. | `profile_modals.dart:333-335`; `proveedor_card.dart:144-147`; `profile_background.dart:44-48`; `assets/img/` sólo tiene `logo_color_noBG.png` | Degradación visual silenciosa en perfil, tarjeta de proveedor y fondo. |

### P1 — navegación, contratos y acciones incompletas

| # | Función | Estado actual | Evidencia | Impacto |
|---:|---|---|---|---|
| 6 | **“Ver mis solicitudes” después de solicitar** | Abre `/solicitudes` sin argumento, por lo que cae en la pestaña 0 = recibidas; el cliente acaba de crear una **enviada**. | `detail_screen.dart:548-550`; `solicitudes_screen.dart:14-20, 163`; `main.dart:105-109` | El usuario no ve la solicitud recién creada y cree que falló. |
| 7 | **Detalle obsoleto tras editar** | “Editar servicio” navega a `/publicar` sin `await` ni recarga al volver. | `detail_screen.dart:508-514` | Título, precio, estado y fotos siguen mostrando la versión anterior. |
| 8 | **Borrar notas de resolución** | La UI envía `null` cuando el campo queda vacío; el backend usa `COALESCE(@notas, resolucion_notas)`, así que conserva la nota anterior. | `admin_repository.dart:135-139`; `AdminController.cs:498-506` | No se puede limpiar una nota ya guardada; sólo reemplazarla por otro texto. |
| 9 | **Solicitudes en el panel admin** | El backend expone `GET /api/admin/solicitudes`, pero no hay método en `AdminRepository` ni pantalla/ruta en el panel. | `AdminController.cs:519-521`; `admin_repository.dart` (sin método); `admin_drawer.dart` (sin sección) | El administrador no puede auditar solicitudes desde la app. |
| 10 | **Guardas de `/home` y `/perfil`** | Ambas rutas son públicas. `/perfil` falla y redirige por 401; `/home` se renderiza sin sesión. | `main.dart:85-86`; `main.dart:134-135` | Deep links dejan al invitado en pantallas de sesión; experiencia inconsistente. |
| 11 | **Redirección de `/login`** | Si se llega a `/login` con sesión abierta, se muestra el formulario; no manda a `/home`. | `main.dart:83`; `login_screen.dart` (sin chequeo de `haySesion`) | Confusión si el usuario vuelve al login desde un enlace. |
| 12 | **Home no escucha cambios de sesión** | `_nombreUsuario` y `_panelAdmin` leen `AuthRepository.usuario.value` en cada build, pero no hay listener; no se reconstruye al cambiar el nombre/rol. | `home_screen.dart:34-37, 107-110` | Saludo o acceso admin pueden quedar obsoletos hasta otra reconstrucción. |
| 13 | **Adjuntos en solicitudes** | `FormSolicitud` filtra todos los campos `TipoCampo.file`; el usuario nunca ve el campo de archivo. | `form_solicitud.dart:42-45`; `solicitud_config.dart` define campos `file` | Las categorías que piden documentos no pueden recibirlos. |
| 14 | **CRUD de categorías** | `AdminCategoriasScreen` sólo cuenta servicios con N llamadas públicas; no hay crear/editar/eliminar ni endpoint admin de categorías. | `admin_categorias_screen.dart:11-47` | Si se espera gestionar categorías, falta backend y UI. |
| 15 | **Evidencias en reportes** | El backend permite hasta 3 imágenes por reporte; la UI de reporte sólo envía tipo, título y descripción. | `ReportesController.cs:119-123`; `profile_modals.dart:819-824` | Reportes sin prueba visual. |

### P2 — deuda funcional y de experiencia

| # | Función | Estado actual | Evidencia | Impacto |
|---:|---|---|---|---|
| 16 | **Enlaces de soporte y cuenta** | “Centro de ayuda”, “Términos”, “Privacidad”, “Contacto” y “Mis servicios” del footer llaman a “próximamente”; algunas rutas ya existen. | `footer_home.dart:95-120`; `home_screen.dart:198` | Navegación muerta en el pie de página. |
| 17 | **Login con Google** | `GoogleGLogo` no se usa en ninguna pantalla; no hay flujo OAuth. | `google_g_logo.dart` (sin referencias); `rg "GoogleGLogo"` sólo encuentra su definición | Si el diseño promete Google, no está implementado. |
| 18 | **Iconos flotantes en móvil** | `AnimacionAmbiental` desactiva `TickerMode` en móvil/reducir movimiento; `FloatingIcons` en `t=0` devuelve `SizedBox.shrink()` para todos los iconos retrasados. | `animacion_ambiental.dart:14-22`; `floating_icons.dart:119-130`; `hero_presentacion.dart:36-38` | En celular el hero puede quedar sin iconos flotantes; el comentario “se ve igual” no se cumple para este widget. |
| 19 | **Variantes de fondo sin uso** | `SeccionFondo` soporta grilla, circuito, estrellas y `ninguno`; sólo se instancia `circuito`. `ninguno` es inalcanzable por el guard. | `section_backgrounds.dart:58-82`; `tarjeta_publicar.dart:21` | Código muerto o feature a medio integrar. |
| 20 | **Enlace de perfil hardcodeado** | “Compartir” copia `https://uniservice.app/perfil/{id}`; no usa configuración de entorno ni una ruta real de la app. | `profile_screen.dart:142-147` | El enlace puede no corresponder al dominio/ruta de despliegue. |
| 21 | **Fechas del panel** | `fechaApi` asume UTC si el string no termina en `Z` ni contiene `+`; un offset negativo (`-05:00`) no se parsea. Hoy el backend entrega UTC, así que no se reprodujo un fallo. | `admin_repository.dart:163-170` | Fragilidad si cambia el serializador o se consume otra API. |
| 22 | **Botones custom y teclado** | Varios botones usan `GestureDetector` (con `Semantics`) pero sin `Focus`/`Shortcuts`; no se activan con Enter/Espacio en web/escritorio. | `auth_widgets.dart:194-196, 270-271`; `app_buttons.dart:43-44, 89-90` | Accesibilidad incompleta para navegación por teclado. |
| 23 | **Filtros admin incompletos** | Reportes soporta `tipo` en la API pero la UI sólo filtra por estado; usuarios soporta `rol` pero la UI sólo activos/suspendidos. | `AdminController.cs:188, 467`; `admin_reportes_screen.dart:98-104`; `admin_usuarios_screen.dart` | Menos control de búsqueda en el panel. |

### 6.1 Cosas que parecen faltar pero sí están

Para evitar falsos positivos en futuras revisiones:

- Moderación de servicios: aprobar, rechazar con motivo y ocultar están completos.
- Perfil: edición, avatar, seguidores/siguiendo y reporte de usuario están completos.
- Servicios: crear, editar, pausar/reanudar, eliminar y gestionar imágenes están completos.
- Solicitudes: crear, aceptar con contraoferta, rechazar con motivo, completar y cancelar.
- Reseñas: crear y editar según el estado de calificación.
- Paginación del explorador: **tiene** guardia `_peticion` y desactiva el botón mientras carga;
  no debe reportarse como carrera sin una reproducción concreta.
- Administración: dashboard, usuarios, servicios, reportes, categorías y bitácora existen;
  el hueco real es la vista de **solicitudes**.

---

## 7. Contratos y decisiones relevantes

- **Identidad por JWT**: los endpoints toman `id_usuario`/`id_proveedor` del token y
  ignoran esos campos en el body. La app no debe enviarlos para “suplantar”.
- **Autorización global**: el `AuthorizeFilter` protege todo por defecto; los endpoints
  públicos llevan `[AllowAnonymous]`. Cualquier ruta nueva debe declarar su política.
- **Elevación admin**: `X-Admin-Elevacion` sólo se envía a `/api/admin/*`; el token
  JWT normal no basta para el panel.
- **Contacto y ubicación**: sin sesión, la API oculta contacto y coordenadas; el detalle
  muestra la invitación a iniciar sesión.
- **Fechas**: la API trabaja en UTC. `fechaApi` normaliza strings sin zona, pero no
  offsets negativos.
- **Paginación**: `PaginaServicios` y `PaginaAdmin<T>` normalizan `items`, `total`,
  `page` y `pageSize`; el explorador y las listas admin dependen de eso.
- **Errores**: `ApiException` conserva `status`, `mensaje` y `datos`; las pantallas
  muestran `campos` cuando el backend devuelve validaciones por campo.

---

## 8. Verificación realizada

| Comprobación | Resultado |
|---|---|
| `flutter pub get` | OK |
| `flutter build web --dart-define=API_URL=http://localhost:5165` | OK |
| `dotnet build` | OK |
| `flutter test` | Pasa |
| `dart analyze` | 4 avisos informativos (`curly_braces_in_flow_control_structures`, `unnecessary_underscores`); sin errores |
| `flutter analyze` | Falla por bug del analysis server (`FormatException: Unexpected end of input`, exit 255); usar `dart analyze` |
| API local | Swagger respondió 200; luego fue detenida y el puerto 5165 quedó libre |

Cobertura de pruebas existente:

- `test/detalle_test.dart`: invitado, servicio inexistente y reintento de error.
- `test/explorador_test.dart`: búsqueda, filtros y paginación.
- `test/modelos_test.dart`: parseo de modelos y helpers.
- `test/perfil_test.dart`: parseo de perfil propio y público.
- `test/widget_test.dart`: arranque del login y encaje sin scroll en 360×780.
- `test/fakes/api_falsa.dart`: `MockClient` compartido.

No hay pruebas de chat, notificaciones, administración ni publicación de servicios.

---

## 9. Pendientes de entorno

- `UniserviceAPI/UniserviceAPI/.env` existe con `Jwt__Key` e
  `InstitutionalEmail__CodeKey` locales, pero la connection string de Supabase sigue
  como placeholder (`CAMBIAR_CONNECTION_STRING`). Sin ella no se pueden probar login,
  catálogo ni admin contra la base real.
- No se ejecutaron migraciones contra Supabase.
- `AGENTS.md` y `README.md` ya documentan comandos, layout y ejecución web.

---

## 10. Próximos pasos sugeridos

1. **Cerrar P0**: pantalla/repositorio de chat, notificaciones reales, coordenadas en
   `DatosServicio` + selector de mapa, reporte de servicio y assets faltantes.
2. **Corregir contratos**: `PUT /api/servicios` no debe borrar lat/lng cuando el cliente
   no las envía; o el cliente debe reenviarlas siempre.
3. **Arreglar navegación**: guardas de `/home` y `/perfil`, redirección de `/login`,
   `await` + recarga tras editar y pestaña correcta en “Ver mis solicitudes”.
4. **Completar admin**: vista de solicitudes, limpieza de notas y filtros `tipo`/`rol`.
5. **Accesibilidad y responsive**: teclado en botones custom, overflow de etiquetas y
   revisar animaciones en móvil.
6. **Pruebas**: agregar casos de chat, notificaciones, admin y publicación; ejecutar
   `dart analyze` y las suites Node cuando se toque API/DB.
