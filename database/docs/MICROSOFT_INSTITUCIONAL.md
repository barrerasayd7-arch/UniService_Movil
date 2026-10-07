# Correo institucional y estudiante activo

`aalfonsoaguilar@unicesar.edu.co` cumple el dominio permitido. Escribir esa dirección no demuestra acceso a la cuenta; recibir un código prueba control del buzón, y entrar por Microsoft prueba autenticación de la identidad. Ninguna de esas dos pruebas garantiza por sí sola matrícula activa: docentes, personal y egresados podrían conservar cuentas del mismo dominio.

## Opción preparada: Microsoft Entra del tenant universitario

TI de la universidad debe autorizar el registro de las aplicaciones y aportar los identificadores reales. El dominio no permite inferir de forma fiable el tenant ni inventar la condición de estudiante.

1. Registrar una API **single tenant** y un cliente móvil en el directorio institucional. Exponer el scope delegado `api://<API_CLIENT_ID>/access_as_user`. Configurar tokens de acceso v2 en la API.
2. Crear en la API un app role con valor **`EstudianteActivo`**, permitido para usuarios/grupos. TI asigna ese rol al grupo institucional de estudiantes activos. Su actualización debe seguir la matrícula: un grupo informal o sin actualización no acredita condición activa. La disponibilidad de asignación por grupo y las licencias deben confirmarse con TI; la asignación directa o sincronización con registro académico son alternativas.
3. Autorizar al cliente móvil para ese scope, dar el consentimiento requerido y configurar el redirect URI exacto para Android/iOS. El móvil es cliente público: no lleva client secret. Usar Authorization Code + PKCE con biblioteca que gestione state/nonce y navegador del sistema.
4. Flutter obtiene un **access token destinado a la API** y lo envía a `POST /api/auth/microsoft-login`. No mandar un token de Microsoft Graph ni interpretar un ID token como permiso de la API.
5. El backend valida firma con discovery/JWKS, emisor del tenant concreto, `tid`, audiencia `aud`, vigencia `exp/nbf`, cliente `azp`, scope `scp=access_as_user`, rol `roles=EstudianteActivo` e identidad de usuario `oid`. Rechaza tokens sin todos los requisitos, de aplicaciones/otros tenants o expirados.
6. Identificar la cuenta por **`(tid, oid)`**, no por correo. Validar además la regla de producto de dominio exacto `@unicesar.edu.co`, normalizado. `email` y `preferred_username` son atributos mutables: no usarlos para conceder el rol académico ni para vincular automáticamente una cuenta antigua.
7. En una transacción: buscar la identidad, comprobar suspensión, crear usuario sólo si no existe y enlazar Microsoft, o renovar la identidad ya enlazada. Guardar `verificado_en=now()` y `verificado_hasta` como el menor de la expiración del token y una hora desde la verificación. Emitir el JWT propio con la misma expiración o más corta. No aceptar del cliente campos como `es_estudiante`, `id_rol` o `verificado_hasta`.
8. En cada operación privada, revisar suspensión y vigencia institucional. 002 incorpora esa revisión en las operaciones de la bolsa; servicios, perfil, chats y demás endpoints anteriores requieren controles equivalentes en la API. La revocación de rol puede tardar hasta la expiración de un token ya emitido; acortar sesiones o usar mecanismos adicionales si TI exige revocación inmediata.

## Cuentas existentes

No dar privilegios por coincidencia de correo ni asignar estado de estudiante a todos los usuarios antiguos. Un vínculo inicial debe realizarse mediante un flujo supervisado que pruebe posesión de la cuenta antigua y de la identidad Microsoft, o una correspondencia autorizada por TI usando object ID y tenant.

La tabla sólo debe actualizarse desde servidor. Para precargar un vínculo sin conceder acceso, usar fechas de verificación **ya expiradas** que cumplan `verificado_hasta > verificado_en`; el primer login Microsoft correcto renovará la vigencia. No añadir JWT/códigos ni datos personales a SQL versionado.

## Si aún no hay colaboración de TI

Se puede desarrollar y probar el esquema y el flujo en un tenant de pruebas. En producción no presentar el dominio como “estudiante verificado”. Una alternativa es validar la matrícula contra un servicio/listado oficial mantenido por la universidad, con autorización y caducidad; requiere construir ese proceso en el servidor. La carpeta no incluye ese servicio ni acceso a los sistemas académicos.

## Cambios fuera de SQL

- Cerrar el registro por contraseña/Google para cuentas nuevas. Dar una respuesta clara para los endpoints antiguos y sustituir la interfaz de registro por Microsoft cuando se implemente.
- Revisar el cambio de correo; un campo de contacto no puede reemplazar la identidad institucional.
- Configurar `Microsoft__TenantId`, `Microsoft__ApiClientId`, `Microsoft__MobileClientId`, `Microsoft__StudentRole=EstudianteActivo` en el servidor. Los tres identificadores pueden ir en configuración pública de Flutter; los secretos se quedan en el servidor.
- Si se opta por Supabase Auth Azure en lugar de la API actual, configurar el tenant Azure y callbacks en el proveedor. Además se requiere un nuevo diseño de vínculo UUID/integer y verificación de estudiantes del lado servidor: activar el proveedor no implementa el rol académico de esta propuesta.

Referencia: [Microsoft: validar audiencia, tenant, sujeto y actor](https://learn.microsoft.com/en-us/entra/identity-platform/claims-validation), [OAuth/PKCE](https://learn.microsoft.com/en-us/entra/identity-platform/v2-oauth2-auth-code-flow), [Supabase Azure](https://supabase.com/docs/guides/auth/social-login/auth-azure).
