-- Sólo lectura. Después de 001 y 002; 003 es una activación posterior.
SELECT * FROM uniservice_mobile.migraciones ORDER BY version;

SELECT c.relname AS tabla, c.relrowsecurity AS rls_activo,
  has_table_privilege('anon', c.oid, 'SELECT,INSERT,UPDATE,DELETE') AS anon_tiene_acceso,
  has_table_privilege('authenticated', c.oid, 'SELECT,INSERT,UPDATE,DELETE') AS authenticated_tiene_acceso
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN (
  'identidades_institucionales', 'habilidades', 'usuario_habilidades', 'perfiles_academicos',
  'peticiones_servicio', 'peticion_habilidades', 'postulaciones_servicio')
ORDER BY c.relname;
-- Esperado: 7 filas, rls_activo=true y ambos accesos=false.

SELECT p.proname, p.prosecdef AS security_definer,
  has_function_privilege('anon', p.oid, 'EXECUTE') AS anon_puede_ejecutar,
  has_function_privilege('authenticated', p.oid, 'EXECUTE') AS authenticated_puede_ejecutar
FROM pg_proc p JOIN pg_namespace n ON n.oid = p.pronamespace
WHERE n.nspname = 'uniservice_mobile' ORDER BY p.proname;
-- Esperado: security_definer=false y accesos=false.

SELECT nombre, activa FROM public.habilidades ORDER BY nombre;

SELECT tgname, tgdeferrable, tginitdeferred FROM pg_trigger
WHERE tgrelid = 'public.usuarios'::regclass
  AND tgname IN ('uniservice_correo_institucional', 'uniservice_identidad_al_registrar');
-- Antes de 003: cero filas; después de 003: dos filas.

SELECT count(*) AS peticiones_sin_habilidades
FROM public.peticiones_servicio p
WHERE NOT EXISTS (SELECT 1 FROM public.peticion_habilidades ph WHERE ph.id_peticion = p.id_peticion);
-- Debe ser cero al crear peticiones mediante crear_peticion().
