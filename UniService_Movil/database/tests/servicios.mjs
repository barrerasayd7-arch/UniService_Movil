import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

// Prueba 008 sobre una copia en memoria de las tablas antiguas de la web (estructura real de
// Supabase, datos inventados). No lee variables ni credenciales y no toca Supabase.
const db = new PGlite();
let assertions = 0;
const rows = async (sql, values = []) => (await db.query(sql, values)).rows;
const one = async (sql, values = []) => (await rows(sql, values))[0];
function check(condition, message) { assert.ok(condition, message); assertions++; }
async function rejects(sql, code, values = []) {
  try { await db.query(sql, values); }
  catch (error) { assert.equal(error.code, code, error.message); assertions++; return; }
  assert.fail(`Se esperaba rechazo ${code}: ${sql}`);
}
const migration = async (name) =>
  db.exec(await readFile(new URL(`../migrations/${name}`, import.meta.url), 'utf8'));
const listar = (pagina, porPagina, categoria, busqueda, orden) => rows(
  'SELECT * FROM uniservice_mobile.listar_servicios($1,$2,$3,$4,$5)', [pagina, porPagina, categoria, busqueda, orden]);
const ids = (lista) => lista.map((s) => s.id_servicio);

try {
  await db.exec(`
    CREATE ROLE anon; CREATE ROLE authenticated;
    CREATE TABLE categorias (id_categoria serial PRIMARY KEY, nombre_categoria varchar(50) NOT NULL);
    INSERT INTO categorias(nombre_categoria) VALUES ('Tutorías'), ('Ensayos y redacción'), ('Proyectos'),
      ('Programación'), ('Diseño'), ('Arriendo de habitaciones'), ('Otros servicios');
    CREATE TABLE usuarios (
      id_usuario integer PRIMARY KEY, nombre varchar(50) NOT NULL, correo varchar(100) NOT NULL UNIQUE,
      estado boolean DEFAULT false, id_rol integer NOT NULL DEFAULT 2,
      universidad varchar(50) DEFAULT 'Sin universidad', avatar varchar(255) DEFAULT 'img/default_avatar.png');
    INSERT INTO usuarios(id_usuario, nombre, correo, estado) VALUES
      (1, 'Ana Proveedora', 'ana@unicesar.edu.co', true),
      (2, 'Beto Cliente', 'beto@unicesar.edu.co', true),
      (3, 'Cuenta Inactiva', 'inactiva@unicesar.edu.co', false);
    CREATE TABLE servicios (
      id_servicio serial PRIMARY KEY,
      id_proveedor integer NOT NULL CONSTRAINT fk_servicio_usuario REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
      titulo varchar(100) NOT NULL, descripcion text NOT NULL,
      id_categoria integer CONSTRAINT fk_servicio_categoria REFERENCES categorias(id_categoria) ON DELETE SET NULL,
      precio_hora numeric NOT NULL, contacto varchar(150), modalidad integer, icono varchar(10),
      disponibilidad integer, fecha_publicacion timestamp DEFAULT now(),
      ubicacion_lat numeric, ubicacion_lng numeric, direccion text);
    CREATE INDEX idx_servicios_categoria_disponible ON servicios(id_categoria, disponibilidad) WHERE disponibilidad > 0;
    CREATE TABLE servicios_imagenes (
      id_imagen serial PRIMARY KEY,
      id_servicio integer NOT NULL CONSTRAINT fk_imagen_servicio REFERENCES servicios(id_servicio) ON DELETE CASCADE,
      url_imagen varchar(255) NOT NULL, es_principal boolean DEFAULT false, fecha_subida timestamp DEFAULT now());
    CREATE INDEX idx_servicios_imagenes_servicio ON servicios_imagenes(id_servicio, fecha_subida);
    CREATE TABLE solicitudes (
      id_solicitud serial PRIMARY KEY,
      id_cliente integer NOT NULL CONSTRAINT fk_solicitud_cliente REFERENCES usuarios(id_usuario),
      id_proveedor integer NOT NULL CONSTRAINT fk_solicitud_proveedor REFERENCES usuarios(id_usuario),
      id_servicio integer NOT NULL CONSTRAINT fk_solicitud_servicio REFERENCES servicios(id_servicio),
      fue_aceptada boolean DEFAULT false, descripcion text, presupuesto numeric, archivo varchar(255),
      estado varchar(20) DEFAULT 'Pendiente', campos_personalizados jsonb DEFAULT '{}');
    CREATE TABLE calificaciones (
      id_calificacion serial PRIMARY KEY,
      id_solicitud integer NOT NULL CONSTRAINT fk_calif_solicitud REFERENCES solicitudes(id_solicitud),
      id_cliente integer NOT NULL CONSTRAINT fk_calif_cliente REFERENCES usuarios(id_usuario),
      id_servicio integer NOT NULL CONSTRAINT fk_calif_servicio REFERENCES servicios(id_servicio),
      puntuacion smallint NOT NULL CHECK (puntuacion BETWEEN 1 AND 5), comentario text,
      fecha_calificacion timestamp DEFAULT now(), fecha_modificacion timestamp,
      CONSTRAINT uq_cliente_servicio UNIQUE (id_cliente, id_servicio));

    -- Triggers y procedimientos de la web, copiados de Supabase.
    CREATE FUNCTION fn_servicio_asignar_imagen_default() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN
      INSERT INTO servicios_imagenes (id_servicio, url_imagen, es_principal)
      VALUES (NEW.id_servicio, 'img/default_servicio.png', TRUE);
      RETURN NEW;
    END $$;
    CREATE TRIGGER tr_servicio_asignar_imagen_default AFTER INSERT ON servicios
      FOR EACH ROW EXECUTE FUNCTION fn_servicio_asignar_imagen_default();
    CREATE FUNCTION fn_validar_max_imagenes() RETURNS trigger LANGUAGE plpgsql AS $$
    BEGIN RETURN NEW; END $$;
    CREATE TRIGGER tr_validar_max_imagenes BEFORE INSERT ON servicios_imagenes
      FOR EACH ROW EXECUTE FUNCTION fn_validar_max_imagenes();
    CREATE FUNCTION sp_obtenerserviciospaginados(integer, integer, integer, text, text)
      RETURNS integer LANGUAGE sql AS 'SELECT 1';
    CREATE FUNCTION sp_guardarcalificacionconaspectos(integer, integer, integer, smallint, text, text)
      RETURNS integer LANGUAGE sql AS 'SELECT 1';

    -- Datos como los deja la API antigua (disponibilidad = -1 = pendiente/pausado).
    INSERT INTO servicios(id_servicio, id_proveedor, titulo, descripcion, id_categoria, precio_hora, modalidad, disponibilidad, fecha_publicacion) VALUES
      (10, 1, 'Tutoría de Cálculo', 'Derivadas e integrales paso a paso', 1, 20000, 0, 0, '2026-09-01'),
      (11, 1, 'Habitación amoblada', 'Cerca de la sede principal', 6, 450000, 0, -1, '2026-09-02'),
      (12, 3, 'Programación oculta', 'Proveedor con cuenta inactiva', 4, 30000, 1, 2, '2026-09-03'),
      (13, 2, 'Programación en Python', 'Proyectos y scripts', 4, 50000, NULL, 1, '2026-09-04');
    INSERT INTO servicios_imagenes(id_servicio, url_imagen, es_principal, fecha_subida) VALUES
      (10, 'https://x.supabase.co/a.jpg', false, '2026-09-01 10:00'),
      (10, 'https://x.supabase.co/portada.jpg', true, '2026-09-01 11:00');
    INSERT INTO solicitudes(id_solicitud, id_cliente, id_proveedor, id_servicio, estado) VALUES
      (100, 2, 1, 10, 'Completada'), (101, 1, 2, 13, 'Completada'), (102, 2, 1, 11, NULL);
    INSERT INTO calificaciones(id_solicitud, id_cliente, id_servicio, puntuacion) VALUES (100, 2, 10, 3), (101, 1, 13, 5);
  `);

  for (const file of ['001_bolsa_y_perfiles.sql', '002_operaciones_servidor.sql', '004_correo_institucional_otp.sql',
    '005_panel_admin.sql', '007_cerrar_acceso_publico.sql', '008_servicios_movil.sql']) await migration(file);

  // Estado de moderación separado de la disponibilidad.
  const servicios = Object.fromEntries((await rows(
    'SELECT id_servicio, estado, disponibilidad, modalidad, unidad_precio FROM servicios')).map((s) => [s.id_servicio, s]));
  check(servicios[10].estado === 'aprobado' && servicios[10].disponibilidad === 0, 'Aprobado conserva su disponibilidad');
  check(servicios[11].estado === 'pendiente' && servicios[11].disponibilidad === 2, 'disponibilidad -1 pasa a pendiente');
  check(servicios[11].unidad_precio === 'mes' && servicios[10].unidad_precio === 'hora', 'Arriendo se cobra por mes');
  check(servicios[13].modalidad === 0, 'Modalidad nula pasa a presencial');
  await rejects("UPDATE servicios SET estado = 'borrado' WHERE id_servicio = 10", '23514');
  await rejects('UPDATE servicios SET disponibilidad = -1 WHERE id_servicio = 10', '23514');
  await rejects('UPDATE servicios SET precio_hora = 0 WHERE id_servicio = 10', '23514');
  await db.exec("INSERT INTO servicios(id_servicio, id_proveedor, titulo, descripcion, id_categoria, precio_hora) VALUES (14, 1, 'Nuevo', 'Recién creado', 5, 1000)");
  check((await one('SELECT estado FROM servicios WHERE id_servicio = 14')).estado === 'pendiente', 'Servicio nuevo nace pendiente');

  // Imágenes: sin la imagen por defecto falsa, con orden y máximo 5.
  check((await one("SELECT count(*)::integer AS n FROM servicios_imagenes WHERE url_imagen LIKE 'img/%'")).n === 0, 'Se borran imágenes por defecto');
  check((await one('SELECT count(*)::integer AS n FROM servicios_imagenes WHERE id_servicio = 14')).n === 0, 'Servicio nuevo sin imagen falsa');
  const portada = await one('SELECT url_imagen FROM servicios_imagenes WHERE id_servicio = 10 AND orden = 0');
  check(portada.url_imagen.endsWith('portada.jpg'), 'La imagen principal pasa a orden 0');
  await rejects("INSERT INTO servicios_imagenes(id_servicio, url_imagen, orden) VALUES (10, 'https://x/b.jpg', 5)", '23514');
  await rejects("INSERT INTO servicios_imagenes(id_servicio, url_imagen, orden) VALUES (10, 'https://x/b.jpg', 1)", '23505');
  await db.exec(`BEGIN;
    UPDATE servicios_imagenes SET orden = 1 - orden WHERE id_servicio = 10;
    COMMIT;`);
  check((await one('SELECT url_imagen FROM servicios_imagenes WHERE id_servicio = 10 AND orden = 1')).url_imagen.endsWith('portada.jpg'),
    'Se pueden intercambiar posiciones en una transacción');

  // Listado público: aprobados de cuentas activas, búsqueda sin tildes, órdenes y paginación.
  check(JSON.stringify(ids(await listar(1, 10, null, null, 'recientes'))) === '[13,10]', 'Lista sólo aprobados de cuentas activas');
  check(JSON.stringify(ids(await listar(1, 10, null, null, 'antiguos'))) === '[10,13]', 'Orden antiguos');
  check(ids(await listar(1, 10, null, null, 'precio-mayor'))[0] === 13, 'Orden precio mayor');
  check(ids(await listar(1, 10, null, null, 'rating-mayor'))[0] === 13, 'Orden mejor calificación');
  check(ids(await listar(1, 10, null, null, 'rating-menor'))[0] === 10, 'Orden peor calificación');
  check(JSON.stringify(ids(await listar(1, 10, 4, null, null))) === '[13]', 'Filtro por categoría');
  for (const texto of ['calculo', 'CÁLCULO', ' tutoria ', 'ana proveedora']) {
    check(JSON.stringify(ids(await listar(1, 10, null, texto, null))) === '[10]', `Busca "${texto}" sin tildes ni mayúsculas`);
  }
  check((await listar(1, 10, null, '%', null)).length === 0, 'Comodines de LIKE se buscan literalmente');
  const pagina2 = await listar(2, 1, null, null, 'recientes');
  check(pagina2.length === 1 && pagina2[0].id_servicio === 10 && Number(pagina2[0].total) === 2, 'Paginación con total');
  const tarjeta = (await listar(1, 10, 1, null, null))[0];
  check(tarjeta.num_resenas === 1 && Number(tarjeta.promedio) === 3 && tarjeta.imagen.startsWith('https://'), 'Tarjeta con reseñas y portada');
  check((await listar(1, 999, null, null, null)).length === 2 && (await listar(-3, 0, null, null, null)).length === 1,
    'Página y tamaño inválidos se acotan');

  // Solicitudes: estados válidos y una sola activa por cliente/servicio.
  check((await one('SELECT estado FROM solicitudes WHERE id_solicitud = 102')).estado === 'Pendiente', 'Estado nulo pasa a Pendiente');
  await rejects('INSERT INTO solicitudes(id_cliente, id_proveedor, id_servicio) VALUES (2, 1, 11)', '23505');
  await rejects("INSERT INTO solicitudes(id_cliente, id_proveedor, id_servicio, estado) VALUES (2, 1, 10, 'Borrada')", '23514');
  await rejects('INSERT INTO solicitudes(id_cliente, id_proveedor, id_servicio) VALUES (1, 1, 10)', '23514');
  const nueva = await one('INSERT INTO solicitudes(id_cliente, id_proveedor, id_servicio) VALUES (2, 1, 10) RETURNING fecha_creacion');
  check(nueva.fecha_creacion !== null, 'Solicitud nueva guarda su fecha');
  check((await one('SELECT fecha_creacion IS NULL AS v FROM solicitudes WHERE id_solicitud = 100')).v, 'Solicitudes antiguas sin fecha inventada');

  // Borrar un servicio arrastra su historial.
  await db.exec('DELETE FROM servicios WHERE id_servicio = 10');
  check((await one('SELECT count(*)::integer AS n FROM solicitudes WHERE id_servicio = 10')).n === 0, 'Borrado arrastra solicitudes');
  check((await one('SELECT count(*)::integer AS n FROM calificaciones WHERE id_servicio = 10')).n === 0, 'Borrado arrastra calificaciones');

  // Limpieza y permisos.
  check((await one("SELECT count(*)::integer AS n FROM pg_proc WHERE proname IN ('sp_obtenerserviciospaginados', 'sp_guardarcalificacionconaspectos', 'fn_servicio_asignar_imagen_default', 'fn_validar_max_imagenes')")).n === 0,
    'Se eliminan procedimientos antiguos');
  check((await one("SELECT has_function_privilege('anon', 'uniservice_mobile.listar_servicios(integer,integer,integer,text,text)', 'EXECUTE') AS v")).v === false,
    'anon no puede ejecutar el listado');
  check((await one("SELECT count(*)::integer AS n FROM uniservice_mobile.migraciones WHERE version = '008_servicios_movil'")).n === 1, '008 registrada');

  console.log(`PASS: ${assertions} comprobaciones de la migración 008 en PostgreSQL/PGlite; sin conexión remota.`);
} finally {
  await db.close();
}
