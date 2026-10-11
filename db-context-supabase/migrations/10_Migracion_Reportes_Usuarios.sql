-- ════════════════════════════════════════════════════════════════
-- MIGRACIÓN: Agregar columna id_usuario_reportado a tabla reportes
-- Y expandir tipos de reporte de usuario
-- Ejecutar en Supabase SQL Editor
-- ════════════════════════════════════════════════════════════════

-- 1. Agregar columna id_usuario_reportado (puede ser NULL para reportes que no son contra un usuario)
ALTER TABLE reportes
ADD COLUMN IF NOT EXISTS id_usuario_reportado INT REFERENCES usuarios(id_usuario) ON DELETE SET NULL;

-- Índice para buscar reportes contra un usuario específico
CREATE INDEX IF NOT EXISTS idx_reportes_usuario_reportado ON reportes(id_usuario_reportado);

-- 2. Actualizar la constraint chk_tipo_reporte para incluir más tipos de reporte de usuario
-- Primero eliminamos la constraint existente
ALTER TABLE reportes DROP CONSTRAINT IF EXISTS chk_tipo_reporte;

-- Luego creamos la nueva con todos los tipos
ALTER TABLE reportes
ADD CONSTRAINT chk_tipo_reporte CHECK (tipo_reporte IN (
    -- Reportes de SERVICIOS
    'servicio_fraude',
    'servicio_inapropiado',
    'contenido_inapropiado',
    'pago_problema',

    -- Reportes de USUARIOS
    'usuario_acoso',
    'usuario_fraude',
    'usuario_abuso',
    'usuario_spam',
    'usuario_suplantacion',
    'usuario_comportamiento',

    -- Reportes GENERALES
    'bug_tecnico',
    'queja_general',
    'sugerencia',
    'otro'
));

-- ════════════════════════════════════════════════════════════════
-- Descripciones de los NUEVOS tipos de reporte de usuario
-- ════════════════════════════════════════════════════════════════
-- usuario_acoso         → Acoso, amenazas, hostigamiento repetitivo
-- usuario_fraude        → Perfil falso, estafa, suplantación con fines de fraude
-- usuario_abuso         → Abuso de la plataforma, explotación de vulnerabilidades
-- usuario_spam          → Envío masivo de mensajes, publicidad no solicitada
-- usuario_suplantacion  → Se hace pasar por otra persona o entidad
-- usuario_comportamiento → Comportamiento inapropiado, lenguaje ofensivo, discriminación
