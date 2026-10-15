# UniService

Plataforma de servicios entre estudiantes de la Universidad Popular del Cesar.

```text
App Flutter ──HTTP/JWT──▶ API .NET 8 ──▶ PostgreSQL (Supabase) + Storage + Brevo (correo)
```

| Carpeta | Contenido |
|---|---|
| `UniserviceAPI/` | Backend ASP.NET Core 8 (controladores, Dockerfile, `.env.example`) |
| `UniService_Movil/` | App Flutter conectada a la API (servicios, solicitudes, perfil, panel admin) |
| `UniService_Movil/database/` | **Migraciones SQL vigentes**, checks y documentación de la base de datos |
| `db-context-supabase/` | Esquema y scripts históricos de la web. **Sólo referencia: no ejecutar en producción** (contiene `DELETE`) |

Todo el proyecto es un solo repositorio git: los cambios de API, base de datos y app se suben juntos desde esta carpeta.

---

## 0. Primera vez en un PC nuevo (Windows)

**Instalar una sola vez:**

| Herramienta | Para qué |
|---|---|
| [Git](https://git-scm.com/) | Clonar el repositorio |
| [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0) | La API |
| [Flutter](https://docs.flutter.dev/get-started/install/windows) (Dart ≥ 3.12) | La app |
| [Android Studio](https://developer.android.com/studio) (SDK + emulador) o un celular Android | Correr la app |
| [Node.js](https://nodejs.org/) y [Docker Desktop](https://www.docker.com/products/docker-desktop/) | Sólo para correr las pruebas de la API |

```powershell
flutter doctor                      # todo en verde, incluido Android toolchain
flutter doctor --android-licenses   # aceptar todo con "y"
start ms-settings:developers        # activar "Modo de desarrollador" (Flutter lo pide para los plugins)
```

**Clonar:**

```powershell
git clone https://github.com/barrerasayd7-arch/UniService_Movil.git UniserviceAPP
cd UniserviceAPP
```

**El único archivo que hay que crear** es el `.env` de la API (sección 1). No hay que tocar la base de datos: el equipo comparte el mismo Supabase y sus migraciones ya las aplica una persona (sección 2).

Después: levantar la API (sección 1) y, en otra terminal, la app (sección 3).

## 1. Levantar el backend en local

1. Copia `UniserviceAPI/.env.example` como **`UniserviceAPI/UniserviceAPI/.env`** (junto a `Program.cs`):

   ```powershell
   copy UniserviceAPI\.env.example UniserviceAPI\UniserviceAPI\.env
   ```

2. Rellena los valores. Las claves reales del equipo se piden por un canal privado (mensaje directo); **nunca** se suben a git ni se pegan en grupos abiertos.

   | Variable | Qué es |
   |---|---|
   | `ConnectionStrings__DefaultConnection` | Conexión a Supabase (Session pooler) |
   | `Jwt__Key` | Firma de las sesiones. **La misma para todo el equipo** |
   | `InstitutionalEmail__CodeKey` | Firma de los códigos OTP del correo |
   | `Brevo__ApiKey`, `Brevo__FromEmail`, `Brevo__FromName` | Envío de correos |
   | `Supabase__Url`, `Supabase__ServiceKey` | Subida de imágenes (Storage) |

3. Ejecuta:

   ```powershell
   cd UniserviceAPI/UniserviceAPI
   dotnet run
   ```

4. Abre <http://localhost:5165/swagger>.

Si la API no arranca con `Configura Jwt__Key...`, el `.env` no está en su sitio o le falta `Jwt__Key`.
Si `send-code`/`register` responden 503, falta `InstitutionalEmail__CodeKey` o la configuración de Brevo.

> En Swagger sólo aparecen los endpoints públicos y los del panel admin. Para los protegidos: haz login, copia el `token` y pégalo en **Authorize**.

## 2. Base de datos

El equipo comparte el mismo proyecto de Supabase: **cada migración se aplica una sola vez** (no cada persona).
Se ejecutan en el SQL Editor de Supabase, en este orden:

| Migración | Estado |
|---|---|
| `001_bolsa_y_perfiles.sql` | Aplicada |
| `002_operaciones_servidor.sql` | Aplicada |
| `003_activar_registro_institucional.sql` | **No aplicar** (era para Microsoft, descartado) |
| `004_correo_institucional_otp.sql` | Aplicada |
| `005_panel_admin.sql` | Aplicada |
| `006_verificacion_180_dias.sql` | Sin confirmar (sólo actualiza datos) |
| `007_cerrar_acceso_publico.sql` | Aplicada |
| `008_servicios_movil.sql` | Aplicada |
| `009_perfil_y_relaciones.sql` | **Obligatoria antes de arrancar la API actual** (lee `usuarios.sesiones_validas_desde` en cada petición con sesión) |
| `010_clave_admin.sql` | **Obligatoria antes de usar `/api/admin`** (contraseña de administrador). Va después de la 009 |

Para saber cuáles están aplicadas: `SELECT * FROM uniservice_mobile.migraciones;`

Detalles, verificaciones y reglas de seguridad: [`UniService_Movil/database/README.md`](UniService_Movil/database/README.md).

**Reglas:** nunca ejecutar `schema-full.sql` ni `supabase_seed_data.sql` en la base real; los cambios de esquema se hacen con una migración nueva numerada (`011_...sql`) en `UniService_Movil/database/migrations/`.

## 3. App Flutter

```powershell
cd UniService_Movil
flutter pub get
flutter run
```

URL del backend en desarrollo según dónde corre la app:

| Dónde | URL |
|---|---|
| Emulador Android | `http://10.0.2.2:5165` |
| Windows / web / simulador iOS | `http://localhost:5165` |
| Celular físico | `http://IP_DE_TU_PC:5165` (misma red Wi-Fi) |

La URL se elige al compilar, sin tocar código: `flutter run --dart-define=API_URL=http://IP_DE_TU_PC:5165`.

### Probar en un celular Android físico

1. **Una sola vez en el PC:**
   - Activa el *Modo de desarrollador* de Windows (`start ms-settings:developers`); Flutter lo necesita para compilar plugins.
   - Acepta las licencias de Android: `flutter doctor --android-licenses`.
   - Abre el puerto de la API en el firewall (PowerShell **como administrador**; la red Wi-Fi debe estar como *Privada*):
     `New-NetFirewallRule -DisplayName "UniService API 5165" -Direction Inbound -Protocol TCP -LocalPort 5165 -Action Allow -Profile Private`
2. **En el celular:** activa *Opciones de desarrollador* → *Depuración USB*, conéctalo por cable y acepta el aviso.
3. **API escuchando en la red:** `cd UniserviceAPI/UniserviceAPI` → `dotnet run --launch-profile celular`.
4. Comprueba desde el navegador del celular que abre `http://IP_DE_TU_PC:5165/swagger`.
5. **App:** `cd UniService_Movil` → `flutter run --dart-define=API_URL=http://IP_DE_TU_PC:5165`.

Sin cable: `flutter build apk --debug --dart-define=API_URL=http://IP_DE_TU_PC:5165` y pasa al celular `build/app/outputs/flutter-apk/app-debug.apk`.
Las versiones debug permiten HTTP; la release exige HTTPS (la API en la nube).

### Pruebas

```powershell
cd UniService_Movil; flutter analyze; flutter test
cd ..\UniserviceAPI\tests\servicios-e2e; node run.mjs   # necesita Docker Desktop abierto
```

`run.mjs` levanta un PostgreSQL desechable en Docker, aplica las migraciones y prueba la API compilada. No toca Supabase ni envía correos.

### Problemas típicos

| Síntoma | Causa |
|---|---|
| `Configura Jwt__Key…` al arrancar la API | El `.env` no está junto a `Program.cs` o le falta `Jwt__Key` |
| 503 al pedir el código del correo | Falta `InstitutionalEmail__CodeKey` o la configuración de Brevo |
| Error de columna `sesiones_validas_desde` | Falta aplicar la migración 009 |
| La app dice "No hay conexión con el servidor" | La API no está corriendo, `API_URL` es incorrecta o el firewall bloquea el puerto 5165 |
| `being used by another process` al compilar la API | Quedó una API vieja corriendo: `Stop-Process -Name UniserviceAPI -Force`. Detén la API siempre con Ctrl+C |
| Las sesiones de un compañero no sirven en tu API | Cada uno tiene una `Jwt__Key` distinta |

## 4. Panel de administración

Endpoints bajo `/api/admin` (usuarios, suspensiones, servicios, reportes, solicitudes y bitácora).

El panel pide **dos contraseñas**: la de la cuenta y una **contraseña de administrador** propia de cada admin, distinta a la de la cuenta (tabla `admin_credenciales`, migración 010).

1. Login normal (`POST /api/auth/login` o `POST /api/admin/auth/login`) con una cuenta `id_rol = 1`.
2. `GET /api/admin/acceso/estado` indica si ya tiene contraseña de administrador.
3. La primera vez (o si la olvidó): código al correo con `send-code`/`verify-code` y `POST /api/admin/acceso/clave` con el `verificacion_token` y la contraseña nueva (mínimo 10 caracteres, letras y números).
4. Las siguientes veces: `POST /api/admin/acceso/verificar`. Tras 5 fallos se bloquea 15 minutos.
5. El token devuelto dura 1 hora y va en la cabecera **`X-Admin-Elevacion`** de cada llamada a `/api/admin/*` (en Swagger: botón Authorize, esquema `AdminElevacion`).

En la app esto es automático: al iniciar sesión con una cuenta admin aparece un aviso y luego la pantalla de la contraseña de administrador. `Admin__MasterPasswordHash` del `.env` es de la web antigua y el panel nuevo no lo usa.

Crear un administrador: registrar una cuenta `@unicesar.edu.co` normal desde la app y promoverla en Supabase:

```sql
UPDATE usuarios SET id_rol = 1, estado = true WHERE correo = 'cuenta@unicesar.edu.co';
```

Los permisos se comprueban contra la base de datos en cada petición: quitar el rol o suspender una cuenta tiene efecto en segundos.

## 5. Despliegue en la nube

La imagen se construye con `UniserviceAPI/UniserviceAPI/Dockerfile` (contexto: esa carpeta) y escucha en el puerto **8080**.
En el panel del hosting define las variables de `.env.example` y además:

| Variable | Valor |
|---|---|
| `ASPNETCORE_ENVIRONMENT` | `Production` (oculta Swagger y el detalle de errores) |
| `AllowedOrigins` | Dominios web permitidos, separados por coma. La app móvil no lo necesita |

En producción la API lee la IP real del cliente desde el proxy del hosting (`X-Forwarded-For`), necesaria para los límites de intentos de login y envío de códigos.

No construyas la imagen con un `.env` o `appsettings.json` con secretos dentro: el `.dockerignore` los excluye, pero la configuración debe venir siempre de las variables del hosting.

## Seguridad: qué nunca va a git

`.env`, `appsettings*.json`, connection strings, `Supabase__ServiceKey`, claves de Brevo, `Jwt__Key`, `InstitutionalEmail__CodeKey`.
El `.gitignore` ya los excluye; antes de cada commit revisa `git status`.
Si una clave llega a subirse por error, hay que **cambiarla** (borrar el commit no basta: ya quedó en el historial).
