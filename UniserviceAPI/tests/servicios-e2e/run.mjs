// Prueba de punta a punta de servicios, solicitudes, calificaciones y moderación admin.
// Requiere Docker y el SDK de .NET. Desde esta carpeta:  node run.mjs
//
// 1. Levanta un PostgreSQL desechable en Docker (puerto 55432) con las tablas antiguas (base_legado.sql).
// 2. Aplica las migraciones 001 → 008 de UniService_Movil/database/migrations.
// 3. Compila la API en una carpeta temporal (no choca con una API que ya esté corriendo).
// 4. Ejecuta e2e.mjs: arranca la API contra esa base, con Storage falso y correos desactivados.
// No usa Supabase, ni la clave de Storage, ni envía correos. El contenedor se borra al terminar.
import { execFileSync, spawnSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const aqui = dirname(fileURLToPath(import.meta.url));
const raiz = join(aqui, '..', '..', '..');
const migraciones = join(raiz, 'UniService_Movil', 'database', 'migrations');
const proyecto = join(raiz, 'UniserviceAPI', 'UniserviceAPI', 'UniserviceAPI.csproj');
const contenedor = 'uniservice-pg-e2e';
const temporal = mkdtempSync(join(tmpdir(), 'uniservice-e2e-'));

const docker = (...args) => execFileSync('docker', args, { stdio: ['pipe', 'pipe', 'pipe'] }).toString();
const psql = (sql) => execFileSync('docker', ['exec', '-i', contenedor, 'psql', '-U', 'postgres', '-v', 'ON_ERROR_STOP=1', '-q'],
  { input: sql, stdio: ['pipe', 'pipe', 'pipe'] });

try {
  spawnSync('docker', ['rm', '-f', contenedor]);
  docker('run', '-d', '--name', contenedor, '-e', 'POSTGRES_PASSWORD=prueba', '-p', '55432:5432', 'postgres:16.4-alpine');
  for (let i = 0; spawnSync('docker', ['exec', contenedor, 'pg_isready', '-U', 'postgres']).status !== 0; i++) {
    if (i > 60) throw new Error('PostgreSQL no arrancó');
    await new Promise((r) => setTimeout(r, 500));
  }
  await new Promise((r) => setTimeout(r, 1500)); // pg_isready responde antes de terminar la inicialización

  psql(readFileSync(join(aqui, 'base_legado.sql'), 'utf8'));
  for (const m of ['001_bolsa_y_perfiles', '002_operaciones_servidor', '004_correo_institucional_otp',
    '005_panel_admin', '007_cerrar_acceso_publico', '008_servicios_movil']) {
    psql(readFileSync(join(migraciones, `${m}.sql`), 'utf8'));
    console.log(`Migración ${m} aplicada`);
  }
  psql(`INSERT INTO verificaciones_correo_institucional(id_usuario, correo, verificado_hasta)
        SELECT id_usuario, correo, now() + interval '180 days' FROM usuarios WHERE id_usuario IN (1, 2, 5);`);

  console.log('Compilando la API…');
  const build = spawnSync('dotnet', ['build', proyecto, '-nologo', '-v', 'q', '-o', join(temporal, 'api')], { stdio: 'inherit' });
  if (build.status !== 0) throw new Error('La API no compila');

  const e2e = spawnSync('node', [join(aqui, 'e2e.mjs'), join(temporal, 'api', 'UniserviceAPI.dll'), temporal], { stdio: 'inherit' });
  process.exitCode = e2e.status ?? 1;
} catch (e) {
  console.error(e.stderr?.toString() || e.message);
  process.exitCode = 1;
} finally {
  spawnSync('docker', ['rm', '-f', contenedor]);
  rmSync(temporal, { recursive: true, force: true });
}
