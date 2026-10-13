# Acceso por código al correo institucional

Decisión actual: verificar control del buzón `@unicesar.edu.co` sin permisos del tenant universitario. El correo puede recibirse en Outlook; UniService lo envía con Brevo. No se consulta Microsoft Graph ni se pide acceso al buzón. Este método no acredita matrícula activa: mostrar **Correo institucional verificado**, nunca **Estudiante activo verificado**.

## Preparar la base de pruebas

1. Mantener respaldo y ejecutar el inventario de la base real.
2. Si aún faltan, aplicar 001 y 002 en una copia de pruebas.
3. Aplicar `migrations/004_correo_institucional_otp.sql` una vez. Para esta alternativa no hace falta ejecutar 003. Si 003 ya se aplicó, 004 adapta sus controles y conserva las identidades Microsoft.
4. Resolver correos duplicados normalizados antes de 004. Confirmar que `usuarios` permite alta con `correo`, `nombre`, `id_rol=2` y `estado=true`, y que tiene `ultima_actividad`. El inventario debe confirmar también que el rol 2 existe y es el rol ordinario correcto. No ejecutar migraciones EF para reconstruir la base existente.

004 conserva los datos actuales. Crea verificaciones de correo y desafíos OTP, con RLS y sin permisos para clientes Supabase. El backend usa la conexión PostgreSQL privada con permisos adecuados. Los nombres antiguos `exigir_estudiante` y `ActiveStudentFilter` se conservan por compatibilidad; después de 004 comprueban acceso institucional, no matrícula.

## Configurar el servidor

En el entorno del backend configurar:

```text
ConnectionStrings__DefaultConnection=<conexión PostgreSQL privada>
Brevo__ApiKey=<clave del servicio de correo>
Brevo__FromEmail=<remitente autorizado en Brevo>
Brevo__FromName=UniService
Jwt__Key=<clave aleatoria privada de al menos 32 bytes>
InstitutionalEmail__CodeKey=<otra clave aleatoria privada de al menos 32 bytes>
```

Usar claves independientes. No poner secretos ni códigos en Git, Flutter, capturas o archivos HTTP versionados. La API ya no arranca con la antigua clave JWT pública de respaldo: configurar una clave nueva también invalida los JWT anteriores. El archivo `.env` local de la API sigue siendo admitido; debe permanecer fuera de Git.

Brevo requiere un remitente autorizado y configuración de entrega apropiada. No hacen falta credenciales del Outlook del destinatario. El proveedor acepta el envío, pero esto no garantiza entrega: revisar el buzón, spam y el estado de entrega en Brevo.

## Probar con Postman o Swagger

Arrancar desde `UniserviceAPI/UniserviceAPI` con `dotnet run --launch-profile http`. La URL local es `http://localhost:5165`; usar HTTPS en producción. Los nuevos endpoints son públicos y aparecen en Swagger. No necesitan un JWT previo.

Enviar `POST /api/auth/institutional-email/send-code` con `Content-Type: application/json`:

```json
{"correo":"tu_cuenta@unicesar.edu.co"}
```

Al recibir el código real, enviar `POST /api/auth/institutional-email/verify-code`:

```json
{"correo":"tu_cuenta@unicesar.edu.co","codigo":"123456","nombre":"Tu nombre"}
```

El código del ejemplo es ficticio. `nombre` es opcional y solo se usa al crear la cuenta. La respuesta correcta incluye `token`, `expires_at` y `user.correo_institucional_verificado=true`. Usar ese JWT como `Authorization: Bearer <token>` en los endpoints de la bolsa. La sesión y la verificación duran una hora; después se pide otro código.

Los códigos contienen seis dígitos, caducan a los diez minutos y se consumen una sola vez. Se guarda únicamente su HMAC con una clave privada y un desafío aleatorio. Un reenvío invalida el código anterior. Cada correo admite un envío por minuto y un máximo de cinco envíos o cinco intentos incorrectos por ventana de una hora; reenviar no reinicia los fallos dentro de la ventana. Envío y verificación se serializan por correo en PostgreSQL.

Cada IP admite veinte llamadas por minuto en cada instancia de API. Con varias réplicas se necesita además un límite compartido en el proxy o servicio de entrada. Detrás de un proxy configurar las cabeceras reenviadas exclusivamente para proxies de confianza para obtener la IP correcta; no confiar indiscriminadamente en `X-Forwarded-For`.

## Cuentas antiguas y errores

- 400: dominio o código inválido, vencido, consumido o intentos agotados.
- 403: cuenta suspendida.
- 409: existe una cuenta con ese correo sin vínculo OTP. No se apropia de esa cuenta automáticamente: requiere un proceso supervisado que compruebe la titularidad de la cuenta anterior y del buzón. No hay endpoint de vinculación administrativa incluido.
- 429: límite de solicitudes, envíos o fallos.
- 503: faltan claves/configuración o Brevo no aceptó el envío. No se devuelve el código al cliente ni se simula éxito.

Alta de usuario, verificación y consumo del código correcto se confirman en una sola transacción. Para cuentas suspendidas o con vínculo pendiente, se consume el código correcto sin conceder sesión. Suspender una cuenta o vencer su verificación bloquea las funciones de la bolsa. Cambiar el correo de una cuenta vinculada exige un proceso supervisado.

## Validación y trabajo pendiente

Las pruebas SQL locales verifican el esquema, RLS, alta transaccional, coincidencia de correo, vencimiento, suspensión y acceso a la bolsa. La compilación valida los nuevos endpoints. Antes de producción probar con un buzón real: entrega y reenvío, código incorrecto, cinco fallos, caducidad, reutilización y dos verificaciones simultáneas (solo una obtiene sesión), caída de Brevo y rollback del alta.

Desde la raíz del workspace, después de compilar, ejecutar `powershell.exe -NoProfile -ExecutionPolicy Bypass -File UniserviceAPI/tests/verify-institutional-email.ps1`. La prueba arranca una API aislada con configuración efímera, sin secretos reales ni envío de correo, y comprueba respuestas HTTP y el límite por IP. No sustituye la prueba completa con PostgreSQL y Brevo.

Las pantallas Flutter siguen usando mocks y no se conectan automáticamente con este cambio. Las rutas antiguas de recuperación por contraseña no alimentan esta verificación; sus códigos no sirven para estos endpoints. Los controles existentes de propiedad y acceso en servicios/chats y demás rutas requieren su propia auditoría. El registro antiguo por contraseña/Google permanece cerrado.

Referencia de envío: [Brevo: correo transaccional](https://developers.brevo.com/docs/send-a-transactional-email).
