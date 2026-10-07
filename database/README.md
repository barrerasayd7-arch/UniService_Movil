# Base de datos de UniService móvil

Esta carpeta amplía la base **existente** de Supabase. No reconstruye ni reemplaza los datos de la página web. El repositorio móvil revisado usa datos mock y no tiene todavía un cliente de Supabase ni llamadas reales a la API.

## Arquitectura que sigue esta propuesta

```text
Flutter → API .NET (JWT, Microsoft, permisos) → PostgreSQL en Supabase
```

Se conserva `public.usuarios.id_usuario` integer y las tablas anteriores (`servicios`, `solicitudes`, chats, reseñas, etc.). La bolsa usa tablas nuevas y no cambia el significado de `solicitudes`.

Esta elección sigue la API de la web y los modelos integer del móvil. Conectar Flutter directamente a Supabase Auth sería otra migración: requiere mapear `auth.users.id` UUID con los usuarios actuales y diseñar sus políticas RLS. Estas migraciones **no habilitan** ese acceso directo ni crean ese mapeo.

## Qué ejecutar en Supabase y en qué orden

1. Obtener un respaldo verificable y probar primero en una copia o proyecto de pruebas. Mantener el respaldo fuera de Git.
2. Ejecutar **`checks/00_inventario.sql`** en SQL Editor. Confirmar `usuarios.id_usuario integer`, `estado boolean`, PK de usuario y columnas obligatorias del alta. Si aparecen tablas nuevas con los mismos nombres, no ejecutar 001 hasta comparar sus definiciones.
3. Ejecutar **`migrations/001_bolsa_y_perfiles.sql`**, completo, una vez. Crea las tablas, índices, RLS, permisos y catálogo inicial de habilidades.
4. Ejecutar **`migrations/002_operaciones_servidor.sql`**, completo. Crea las operaciones transaccionales para el backend.
5. Ejecutar **`checks/01_verificar_migraciones.sql`** y comprobar los resultados descritos en sus comentarios.
6. Implementar y probar Microsoft y los endpoints de servidor descritos en `docs/INTEGRACION_API.md` y `docs/MICROSOFT_INSTITUCIONAL.md`.
7. **Sólo después de probar ese backend**, ejecutar **`migrations/003_activar_registro_institucional.sql`**. Bloquea altas antiguas que no vinculan Microsoft en la misma transacción y cambios ordinarios de correo de cuentas vinculadas. También añade unicidad de correo sin distinguir mayúsculas ni espacios; resolver duplicados antes según el inventario.
8. Repetir las verificaciones y las pruebas de aceptación de `docs/INTEGRACION_API.md` con cuentas de pruebas de Microsoft.

Cada archivo usa `BEGIN/COMMIT`: si falla, se revierte ese archivo. No ejecutar 001 o 003 dos veces; el error por objetos/versiones existentes evita interpretar silenciosamente una instalación distinta como válida. 002 permite actualizar sus funciones.

**No ejecutar el antiguo `schema-full.sql` ni `supabase_seed_data.sql` en producción:** el material de la web contiene `DELETE FROM usuarios`, servicios y otras tablas, y reinicios de secuencias. Tampoco hay allí un `CREATE TABLE usuarios` que permita reconstruir la base original. Hace falta exportar la estructura real sin datos/secretos para tener un contexto completo y reproducible; `checks/00_inventario.sql` ayuda a obtenerlo pero no sustituye ese dump.

## Tablas nuevas

| Tabla | Propósito |
|---|---|
| `identidades_institucionales` | Vincula usuario integer con tenant + object ID de Microsoft y vigencia de verificación |
| `habilidades` | Catálogo administrado, con opción de desactivar una habilidad |
| `usuario_habilidades` | Habilidades declaradas, nivel y descripción breve |
| `perfiles_academicos` | Programa, semestre, sede, disponibilidad y enlace HTTPS al portafolio |
| `peticiones_servicio` | Necesidades abiertas publicadas por estudiantes |
| `peticion_habilidades` | Habilidades requeridas por cada petición |
| `postulaciones_servicio` | Propuestas de candidatos, precio y decisión |

Los perfiles académicos y niveles de habilidad son **autodeclarados**. No prueban matrícula ni competencia. No se almacenan carnés, documentos de identidad o certificados en estas tablas.

## Cómo funciona la bolsa

El estudiante publica una petición con 1–10 habilidades, modalidad, presupuesto opcional en COP y plazo de hasta 90 días. Otro estudiante la ve en su feed si tiene **al menos una habilidad coincidente**. El feed ordena primero por número de coincidencias y después por publicación reciente; también permite explorar todas las abiertas o las propias.

Sólo un estudiante verificado puede postularse. No puede ser el autor, la petición debe estar abierta y vigente, y debe existir una habilidad coincidente. Sólo hay una propuesta por usuario/petición. El autor elige un candidato: su propuesta queda aceptada, las demás rechazadas y la petición asignada. La operación bloquea la fila de petición y un índice permite sólo una propuesta aceptada. Posteriormente el autor puede completar o cancelar.

La expiración se calcula en las consultas; una petición puede seguir guardada como `abierta` y tener plazo vencido, pero ya no se recomienda ni admite propuestas. La verificación institucional se renueva al iniciar sesión Microsoft; el autor y el candidato deben tener verificación vigente al aceptar. No se añade push, pagos, comentarios de foro ni contratación automática a las solicitudes antiguas.

## Seguridad y alcance

- Las tablas nuevas tienen RLS y no conceden permisos a `anon`, `authenticated` ni `PUBLIC`. Las funciones de `uniservice_mobile` tampoco son ejecutables por esos roles y son `SECURITY INVOKER`.
- El servidor usa su conexión PostgreSQL privada. El propietario de las tablas mantiene acceso. Si la API usa un rol restringido distinto del propietario, debe configurarse una política exclusiva de ese rol y permisos concretos; no solucionar esto concediendo acceso a `authenticated` o desactivando RLS.
- Los argumentos `p_usuario` se extraen del JWT **en el servidor**. Las funciones son herramientas de servidor; no validan una firma Microsoft ni un JWT por sí mismas. No se exponen como RPC de cliente.
- No incluir `service_role`, contraseña PostgreSQL, connection string, secreto Microsoft o clave de firma del backend en Flutter/Git.
- Estas migraciones no cambian los permisos de las tablas ni las funciones antiguas. El inventario identifica su situación; hace falta auditarlas antes de habilitar cualquier acceso directo. Las cuentas antiguas siguen en la base, pero no reciben condición de estudiante activo automáticamente.
- 003 valida nuevas altas; no impide por sí sola que el backend antiguo siga emitiendo JWT a cuentas existentes. La API debe exigir la verificación institucional para toda operación privada que se reserve a estudiantes.

## Validación incluida

`tests/` ejecuta las migraciones y casos de seguridad/negocio contra PostgreSQL en memoria mediante PGlite, con una estructura mínima simulada de usuarios y los roles de Supabase. No se conecta al Supabase real. Ver `tests/README.md` para ejecución y límites.

## Fuentes

- [RLS, grants y claves de servidor de Supabase](https://supabase.com/docs/guides/database/postgres/row-level-security)
- [Validación de identidad y autorización por Microsoft](https://learn.microsoft.com/en-us/entra/identity-platform/claims-validation)
- [Flujo OAuth con PKCE para móvil](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow)
- [Azure/Microsoft con Supabase Auth, para una futura arquitectura directa](https://supabase.com/docs/guides/auth/social-login/auth-azure)
