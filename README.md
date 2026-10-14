# UniService

Plataforma de servicios entre estudiantes de la Universidad Popular del Cesar.

```text
App Flutter ──HTTP/JWT──▶ API .NET 8 ──▶ PostgreSQL (Supabase) + Storage + Brevo (correo)
```

| Carpeta | Contenido |
|---|---|
| `UniserviceAPI/` | Backend ASP.NET Core 8 (controladores, Dockerfile, `.env.example`) |
| `UniService_Movil/` | App Flutter (por ahora usa datos mock; la conexión a la API está en curso) |
| `UniService_Movil/database/` | **Migraciones SQL vigentes**, checks y documentación de la base de datos |
| `db-context-supabase/` | Esquema y scripts históricos de la web. **Sólo referencia: no ejecutar en producción** (contiene `DELETE`) |

Todo el proyecto es un solo repositorio git: los cambios de API, base de datos y app se suben juntos desde esta carpeta.

---

## 1. Levantar el backend en local

**Requisitos:** [.NET 8 SDK](https://dotnet.microsoft.com/download/dotnet/8.0).

1. Copia `UniserviceAPI/.env.example` como **`UniserviceAPI/UniserviceAPI/.env`** (junto a `Program.cs`).
2. Rellena los valores. Las claves reales del equipo se piden por un canal privado; **nunca** se suben a git ni se pegan en grupos abiertos.
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
| `005_panel_admin.sql` | Aplicar antes de usar `/api/admin` |

Detalles, verificaciones y reglas de seguridad: [`UniService_Movil/database/README.md`](UniService_Movil/database/README.md).

**Reglas:** nunca ejecutar `schema-full.sql` ni `supabase_seed_data.sql` en la base real; los cambios de esquema se hacen con una migración nueva numerada (`006_...sql`) en `UniService_Movil/database/migrations/`.

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

## 4. Panel de administración

Endpoints bajo `/api/admin` (usuarios, suspensiones, servicios, reportes, solicitudes y bitácora).
Login: `POST /api/admin/auth/login` con correo y contraseña de una cuenta con `id_rol = 1`.

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
