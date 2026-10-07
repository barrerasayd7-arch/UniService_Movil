# Pruebas de las migraciones

Requiere Node.js compatible con PGlite y npm. Desde esta carpeta:

```powershell
npm ci
npm test
```

El script crea PostgreSQL en memoria y una tabla de usuarios **mínima y simulada**. Ejecuta las tres migraciones, matching, postulaciones, permisos, transiciones y activación del registro. No lee `.env`, no usa credenciales y no modifica Supabase.

Estas pruebas no sustituyen la copia de pruebas de la base real, el login Microsoft, el backend ni Flutter. PGlite usa una única conexión: no se verifican aquí dos aceptaciones concurrentes reales; esa comprobación debe hacerse con dos conexiones PostgreSQL en staging. Los bloqueos e índice único están incluidos para proteger esa operación.

Los fixtures son datos inventados sólo en memoria; no deben cargarse en producción.
