-- Sólo lectura. Ejecutar primero en SQL Editor. No devuelve contraseñas ni datos personales.
SELECT version() AS postgres_version;

SELECT table_schema, table_name FROM information_schema.tables
WHERE table_schema IN ('public', 'uniservice_mobile') AND table_type = 'BASE TABLE'
ORDER BY table_schema, table_name;

SELECT table_name, column_name, data_type, is_nullable, column_default
FROM information_schema.columns WHERE table_schema = 'public'
  AND table_name IN ('usuarios', 'servicios', 'solicitudes', 'chats', 'mensajes', 'rol_usuarios')
ORDER BY table_name, ordinal_position;

SELECT c.relname AS tabla, pg_get_constraintdef(co.oid) AS restriccion
FROM pg_constraint co JOIN pg_class c ON c.oid = co.conrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relname IN ('usuarios', 'chats', 'solicitudes')
ORDER BY c.relname, co.conname;

SELECT c.relname AS tabla, c.relrowsecurity AS rls_activo, pg_get_userbyid(c.relowner) AS propietario
FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public' AND c.relkind = 'r' ORDER BY c.relname;

SELECT schemaname, tablename, policyname, roles, cmd, qual, with_check
FROM pg_policies WHERE schemaname IN ('public', 'uniservice_mobile') ORDER BY tablename, policyname;

SELECT table_name, grantee, privilege_type FROM information_schema.role_table_grants
WHERE table_schema = 'public' AND grantee IN ('anon', 'authenticated') ORDER BY table_name, grantee;

SELECT routine_schema, routine_name, security_type FROM information_schema.routines
WHERE routine_schema = 'public' ORDER BY routine_name;

-- Verificaciones agregadas de compatibilidad, sin mostrar correos.
SELECT
  count(*) AS usuarios_existentes,
  count(*) FILTER (WHERE correo IS NULL) AS correos_nulos,
  count(*) FILTER (WHERE lower(trim(correo)) ~ '^[a-z0-9][a-z0-9._+-]*@unicesar[.]edu[.]co$') AS correos_institucionales,
  count(*) FILTER (WHERE lower(trim(correo)) !~ '^[a-z0-9][a-z0-9._+-]*@unicesar[.]edu[.]co$') AS otros_correos
FROM public.usuarios;

SELECT count(*) AS grupos_correo_duplicado FROM (
  SELECT lower(trim(correo)) FROM public.usuarios WHERE correo IS NOT NULL
  GROUP BY lower(trim(correo)) HAVING count(*) > 1
) d;

-- Falta un dump de estructura completo de la base actual. schema-full.sql antiguo
-- es una concatenación de migraciones + seeds destructivos, no un esquema inicial.
