# Actualizar después de mezclar `seguridad` en `main`

> **Resumen:** haz copia de tu rama, trae `main`, reinstala paquetes. Si sale un error, búscalo en la tabla de la sección 3.

## 1. Lo básico (3 pasos)

| Paso | Comando | Para qué |
|---|---|---|
| 1 | `git branch respaldo` | Copia de seguridad de tu rama actual |
| 2 | `git fetch origin` y luego `git checkout main` y `git pull origin main` | Traer lo nuevo |
| 3 | API: `dotnet restore`. App: `flutter pub get` | Reinstalar paquetes |

## 2. Qué cambió

| Qué | Antes | Ahora |
|---|---|---|
| Id de la app | `com.example.app_uniservice` | `edu.upc.uniservice` |
| Firma del release | Llave de debug | Llave propia (no está en git) |
| Manifest | Sin reglas | Backups y tráfico en claro desactivados |
| Release | Sin ofuscar | R8 y ofuscación |
| Endpoint `verify-admin-master` | Existía | Eliminado |
| Paquetes de la API | SqlServer y Google.Apis.Auth | Quitados. JwtBearer 8.0.34 y Pkcs 11.0.0 |

## 3. Si te sale un error

| Qué ves | Qué pasó | Solución |
|---|---|---|
| "Your local changes would be overwritten" | Tienes cambios sin guardar | `git stash`, luego `git pull origin main`, luego `git stash pop` |
| Tu rama quedó atrás | `main` avanzó | `git checkout mi-rama` y `git merge origin/main` |
| `CONFLICT (content)` | Tocaste el mismo archivo que `main` | Mira la tabla de la sección 4 |
| API: `SqlServerModelBuilderExtensions no existe` | Línea vieja en `Migrations` | Borra esa línea en `AppDbContextModelSnapshot.cs` y en `...InitialPostgres.Designer.cs`, o toma esos archivos de `main` |
| API: error con `UseSqlServer` o `Google.Apis` | Tu código usa un paquete que ya se quitó | Quita ese código. **No reinstales el paquete** |
| API: "being used by another process" | Hay una API vieja corriendo | `Stop-Process -Name UniserviceAPI -Force` |
| API: "Configura Jwt__Key..." | Falta el `.env` junto a `Program.cs` | Créalo a partir de `.env.example` |
| `/api/auth/verify-admin-master` da 404 | Se eliminó a propósito | El panel usa `/api/admin/acceso` |
| App: errores raros de Gradle | Caché vieja | `flutter clean` y `flutter pub get` |
| Aparecen 2 apps "UniService" en el celular | Cambió el id | Desinstala la vieja |
| "App no instalada" | Mismo id pero otra firma | Desinstala la versión anterior |
| R8: "Missing class ..." | Falta una regla | Manda el error completo al grupo. `--no-shrink` solo para diagnosticar, no para entregar |
| Release: error de firma o keystore | No tienes `key.properties` | Mira la sección 5 |
| Release: "No hay conexión con el servidor" | URL con `http://` o API apagada | Usa `https://` y revisa que la API esté corriendo |

## 4. Conflictos: qué conservar

Abre el archivo, busca `<<<<<<<`, decide qué se queda y borra las líneas de marcas (`<<<<<<<`, `=======`, `>>>>>>>`). Luego `git add archivo` y `git commit`. Si te enredas: `git merge --abort`.

| Archivo | Debe quedar |
|---|---|
| `AndroidManifest.xml` | `allowBackup="false"` y `usesCleartextTraffic="false"` en `<application>` |
| `android/app/build.gradle.kts` | `edu.upc.uniservice`, bloque `signingConfigs` y R8 en `release` |
| `AuthController.cs` | **Sin** `VerifyAdminMaster`, `_adminAttempts` ni `using Google.Apis.Auth;` |
| `UniserviceAPI.csproj` | **Sin** SqlServer ni Google.Apis.Auth. Con JwtBearer 8.0.34 y Pkcs 11.0.0 |
| `.env.example` | Sin `Admin__MasterPasswordHash` |
| `pubspec.lock` | El de `main`, y luego `flutter pub get` |

## 5. Compilar un release

`flutter run` (debug) **no necesita** llave. El release sí.

1. Pide el `.jks` al responsable **por privado** (nunca por grupo abierto ni por git).
2. Guárdalo **fuera** del repositorio.
3. Crea `android/key.properties`:
   ```
   storePassword=TU_CLAVE
   keyPassword=TU_CLAVE
   keyAlias=uniservice
   storeFile=C:/ruta/uniservice-release.jks
   ```
4. Crea `config/prod.json` (está en `.gitignore`), sin barra al final:
   ```
   { "API_URL": "https://la-url-del-backend" }
   ```
5. Compila:
   ```
   flutter build apk --release --obfuscate --split-debug-info=build/symbols --dart-define-from-file=../config/prod.json
   ```

## 6. Checklist al terminar

- [ ] `dotnet build` sin errores
- [ ] `flutter pub get` sin errores
- [ ] `flutter run` abre la app e inicia sesión
- [ ] `git status` no muestra `.jks`, `key.properties` ni `.env`

## 7. Reglas de oro

- **Nunca** subas `.jks`, `key.properties`, `.env`, claves ni contraseñas, ni en capturas.
- Revisa `git status` antes de cada commit.
- No uses `git push --force` ni `git reset --hard` sin avisar al grupo.
- Si un secreto llega a subirse, hay que **cambiarlo**: borrar el commit no basta.