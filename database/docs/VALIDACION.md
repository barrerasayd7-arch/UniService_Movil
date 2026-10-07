# Alcance de la revisión y validación

## Material revisado

- Repositorio `UniService_Movil`: dependencias, modelos de usuario/servicio, registro y formularios. Encontrado: interfaz Flutter con mocks, sin cliente de Supabase ni API conectada.
- Material del proyecto web: rutas, autenticación, perfiles, solicitudes y chat .NET; archivos de `db-context-supabase`. Encontrado: usuarios integer y JWT propio, PostgreSQL, funciones/migraciones concatenadas con seeds destructivos; no esquema inicial completo.

## Comprobaciones locales

Las tres migraciones se ejecutaron contra PostgreSQL/PGlite en memoria. Las pruebas verifican:

- Creación de esquema, tablas, restricciones, funciones y registro de versiones.
- Conservación de usuarios anteriores, incluidos correos externos existentes.
- Feed por habilidades, exploración de abiertas, propias y paginación.
- Reemplazo atómico de habilidades y rechazo de duplicados/niveles incorrectos.
- Autor no se postula; candidato requiere coincidencia; una postulación por usuario/petición.
- Autor ve candidatos, candidato ve su propuesta y terceros ninguna.
- Elección de un candidato, rechazo del resto, índice de unicidad y transiciones de estado.
- Peticiones vencidas o cerradas, presupuesto negativo y referencias de habilidades inválidas.
- Roles `anon`/`authenticated` sin SELECT, INSERT, UPDATE, DELETE o acceso a funciones nuevas.
- Registro institucional: dominio parecido rechazado, alta sin vínculo revertida y alta transaccional usuario+identidad aceptada; normalización y unicidad de correo.

## Lo que falta comprobar en el entorno real

No se accedió al proyecto Supabase remoto ni se modificaron sus datos. No se ha exportado su estructura real. La tabla de usuarios usada por las pruebas es una simulación mínima, por lo que columnas obligatorias, triggers, políticas y permisos actuales pueden requerir ajustes después del inventario.

No se ha probado login Microsoft real, rol de estudiante activo, licencias/consentimiento del tenant, integración Flutter/.NET ni notificaciones. Tampoco se ha probado aceptación concurrente con dos conexiones: PGlite sólo usa una. El bloqueo `FOR UPDATE` y el índice parcial están incluidos y deben comprobarse en staging PostgreSQL.

La carpeta es una propuesta de migración validada localmente y una guía para integración, no un despliegue ni una app conectada. Las funciones y la activación del registro exigen una API de servidor que valide Microsoft; SQL por sí solo no acredita matrícula.
