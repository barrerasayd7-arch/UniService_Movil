# Contrato para integrar la base con la app

Este documento describe trabajo pendiente de API/Flutter. En este repositorio sólo se añade la carpeta de base de datos; no se modifican pantallas, dependencias ni backend.

El móvil actual usa IDs integer y mocks. Sus comentarios mencionan `/api/services`, pero la API web revisada declara `/api/Servicios`: confirmar y unificar las rutas reales al conectar el cliente.

## Endpoints propuestos

Todos exigen JWT validado, cuenta activa y verificación institucional vigente. El servidor extrae el usuario del token; no recibe `id_usuario` o `id_autor` como autoridad del cliente.

| Operación HTTP propuesta | Operación de base / regla |
|---|---|
| `POST /api/auth/microsoft-login` | Validar token Microsoft y crear/vincular/renovar en transacción, según MICROSOFT_INSTITUCIONAL.md |
| `GET /api/bolsa/habilidades` | Leer catálogo `habilidades` con `activa=true` |
| `GET /api/bolsa/perfiles/{id}/habilidades` | Leer habilidades/niveles/detalles; no devolver correo o datos de verificación |
| `PUT /api/bolsa/mi-perfil/habilidades` | `uniservice_mobile.guardar_habilidades(usuario, jsonb)`; reemplazo completo, máximo 20 |
| `GET /api/bolsa/mi-perfil/academico` | Leer perfil académico propio |
| `PUT /api/bolsa/mi-perfil/academico` | Upsert con usuario del JWT; programa/semestre/sede/disponibilidad/portafolio HTTPS; actualizar `actualizado_en` |
| `POST /api/bolsa/peticiones` | `crear_peticion(...)` devuelve ID; 1–10 habilidades, fecha UTC, textos limitados, presupuesto COP opcional |
| `GET /api/bolsa/peticiones?recomendadas=true&propias=false&pagina=1&limite=20` | `obtener_peticiones(...)`; hasta 50 por página |
| `GET /api/bolsa/peticiones/{id}` | Leer detalle; para cerradas, permitir sólo autor y participantes según política de producto |
| `POST /api/bolsa/peticiones/{id}/postulaciones` | `postular(...)`; propuesta y precio opcional, una por candidato |
| `GET /api/bolsa/peticiones/{id}/postulaciones` | `obtener_postulaciones(...)`; autor ve propuestas, candidato sólo la propia, terceros ninguna |
| `POST /api/bolsa/peticiones/{id}/postulaciones/{postulacion}/aceptar` | `aceptar_postulacion(...)` devuelve ID del proveedor; usar transacción también para chat |
| `PATCH /api/bolsa/peticiones/{id}/estado` | `cambiar_estado(...)`; sólo completar asignada o cancelar abierta/asignada |

Las funciones usan `SECURITY INVOKER`: se llaman con una conexión privada de servidor con permisos sobre esas tablas. Nunca habilitar el esquema `uniservice_mobile` como API pública ni dar permisos de ejecución al cliente para que pueda elegir `p_usuario`.

Ejemplo de cuerpo para guardar habilidades:

```json
{"habilidades": [{"id_habilidad": 2, "nivel": "intermedio", "detalle": "Interfaces Flutter y consumo de API"}]}
```

El catálogo asigna los IDs; no codificarlos fijos en Flutter. El servidor pasa el arreglo `habilidades` como JSONB a la función.

Ejemplo de petición:

```json
{
  "titulo": "Necesito ayuda con una pantalla Flutter",
  "descripcion": "Busco apoyo para revisar el diseño y conectar el formulario a una API.",
  "presupuesto": 50000,
  "modalidad": "virtual",
  "fecha_limite": "2026-10-20T23:00:00Z",
  "habilidades": [2]
}
```

La fecha es un ejemplo, no un valor predeterminado. La API debe validar modelos, longitudes, límites y JSON, además de las restricciones SQL. Usar parámetros Npgsql; no concatenar texto del cliente.

## Errores y transacciones

| SQLSTATE | Traducción HTTP sugerida |
|---|---|
| `42501` | 403, sin verificación/permisos; cuando caduca la sesión pedir login Microsoft |
| `P0002` | 404 o conflicto de postulación no disponible según contexto |
| `22023`, `23514`, `23502`, `22001`, `22P02` | 400, entrada inválida |
| `23505` | 409, correo/propuesta duplicados o candidato ya elegido |
| `23503` | 400/409, referencia inexistente |

Mostrar mensajes controlados, no el SQL, la connection string ni la excepción completa. Si falla una operación de varios pasos, revertir toda su transacción. Tras aceptar, crear/reutilizar un chat con la pareja ordenada `(min(id_autor,id_proveedor), max(...))` sólo si el esquema real `chats` coincide con el inventario. No emitir notificaciones hasta confirmar commit.

Esta propuesta usa el feed de coincidencias para “que les aparezca la solicitud”. Push con Firebase/APNs, alertas persistentes, comentarios y búsqueda semántica no están implementados en SQL.

## Revisión de seguridad de la web que afecta la migración

En el código original revisado se encontraron registro Google/correo libre, claves JWT de respaldo, permisos de actualización de perfiles y avatares sin validación suficiente del propietario y un hub de chat que acepta IDs enviados por cliente. No trasladar esa confianza a Flutter: auditar identidad/rol/propiedad en cada ruta, autenticar el hub y comprobar participantes. Las migraciones nuevas no corrigen automáticamente esos controladores antiguos ni despliegan las modificaciones hechas anteriormente en la otra carpeta.

La tabla `identidades_institucionales` conserva vigencia central; las funciones de la bolsa comprueban suspensión y expiración. Si se exige Microsoft para toda la plataforma, añadir el mismo control a todas las rutas privadas y revisar los JWT ya emitidos, la clave de firma y sesiones antiguas. No conservar una clave de respaldo conocida.

## Pruebas de aceptación antes de activar 003

1. Microsoft real: estudiante activo entra; cuenta de otro tenant, personal sin rol, token Graph, token expirado y token alterado son rechazados sin crear usuarios.
2. Cuenta antigua con el mismo correo no se vincula automáticamente ni obtiene matrícula activa.
3. Alta completa de usuario+identidad en una transacción pasa 003. Alta por contraseña o Google sin identidad falla. Un dominio parecido (`unicesar.edu.co.ejemplo.com`) falla.
4. Perfil: un usuario edita sus habilidades y datos; no puede editar otro usuario ni su estado institucional/rol.
5. Petición Flutter se guarda; candidatos con una coincidencia la ven; sin coincidencia sólo al explorar todas y no pueden postularse hasta declarar una habilidad relacionada.
6. No puede postularse el autor; una propuesta duplicada falla; peticiones vencidas/canceladas/asignadas no admiten nuevas propuestas.
7. Sólo el autor ve las propuestas completas y decide. Intentar dos aceptaciones simultáneas con dos conexiones PostgreSQL: exactamente una gana y no se duplica candidato/chat.
8. Completar una abierta falla; completar una asignada funciona; cancelar rechaza las propuestas y deja historial.
9. Suspender o expirar verificación bloquea acciones. Usar roles `anon`/`authenticated` no permite consultar/modificar las nuevas tablas o funciones.
10. Las cuentas/servicios/solicitudes antiguas permanecen intactas después de 001 y 002. Exportar estructura completa y repetir en una copia real antes de producción.
