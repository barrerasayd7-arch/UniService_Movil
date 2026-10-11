-- ===================================================
-- ARCHIVO: 02_Create_Chat_Tables.sql
-- ===================================================

-- ════════════════════════════════════════════════════════════════
-- FASE 1: Sistema de Chat en Tiempo Real
-- Ejecutar en Supabase SQL Editor o en tu cliente PostgreSQL
-- ════════════════════════════════════════════════════════════════

-- 1. Agregar campo ultima_actividad a usuarios (para estado online/offline)
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS ultima_actividad TIMESTAMP DEFAULT NOW();

-- 2. Tabla de conversaciones (chats entre dos usuarios)
CREATE TABLE IF NOT EXISTS chats (
    id_chat SERIAL PRIMARY KEY,
    id_usuario1 INT NOT NULL,
    id_usuario2 INT NOT NULL,
    fecha_creacion TIMESTAMP DEFAULT NOW(),
    ultimo_mensaje TIMESTAMP,
    CONSTRAINT uq_chat_usuarios UNIQUE (id_usuario1, id_usuario2),
    CONSTRAINT fk_chat_u1 FOREIGN KEY (id_usuario1) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_chat_u2 FOREIGN KEY (id_usuario2) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- 3. Tabla de mensajes
CREATE TABLE IF NOT EXISTS mensajes (
    id_mensaje SERIAL PRIMARY KEY,
    id_chat INT NOT NULL,
    id_remitente INT NOT NULL,
    id_destinatario INT NOT NULL,
    mensaje TEXT NOT NULL,
    fecha_envio TIMESTAMP DEFAULT NOW(),
    leido BOOLEAN DEFAULT FALSE,
    tipo VARCHAR(20) DEFAULT 'texto',
    CONSTRAINT fk_msg_chat FOREIGN KEY (id_chat) REFERENCES chats(id_chat) ON DELETE CASCADE,
    CONSTRAINT fk_msg_remitente FOREIGN KEY (id_remitente) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_msg_destinatario FOREIGN KEY (id_destinatario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE
);

-- 4. Índice para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_mensajes_chat ON mensajes(id_chat, fecha_envio DESC);
CREATE INDEX IF NOT EXISTS idx_mensajes_destinatario_leido ON mensajes(id_destinatario, leido);
CREATE INDEX IF NOT EXISTS idx_chats_usuario1 ON chats(id_usuario1, ultimo_mensaje DESC);
CREATE INDEX IF NOT EXISTS idx_chats_usuario2 ON chats(id_usuario2, ultimo_mensaje DESC);


-- ===================================================
-- ARCHIVO: 07_Migracion_Formularios_Dinamicos.sql
-- ===================================================

-- =====================================================
-- MIGRACIÓN: Formularios dinámicos + Google Maps + Imágenes
-- Fecha: 2026-05-19
-- =====================================================

-- 1. NUEVAS COLUMNAS EN servicios PARA GOOGLE MAPS
ALTER TABLE servicios ADD COLUMN IF NOT EXISTS ubicacion_lat DECIMAL(10, 8) DEFAULT NULL;
ALTER TABLE servicios ADD COLUMN IF NOT EXISTS ubicacion_lng DECIMAL(11, 8) DEFAULT NULL;
ALTER TABLE servicios ADD COLUMN IF NOT EXISTS direccion TEXT DEFAULT NULL;

-- 2. NUEVA COLUMNA EN solicitudes PARA CAMPOS PERSONALIZADOS POR CATEGORÍA
ALTER TABLE solicitudes ADD COLUMN IF NOT EXISTS campos_personalizados JSONB DEFAULT '{}';

-- 3. ACTUALIZAR TRIGGER DE IMÁGENES PARA LIMITAR A 5
CREATE OR REPLACE FUNCTION fn_servicio_asignar_imagen_default()
RETURNS TRIGGER AS $$
BEGIN
    -- Solo insertar imagen default si no hay imágenes
    INSERT INTO servicios_imagenes (id_servicio, url_imagen, es_principal)
    VALUES (NEW.id_servicio, 'img/default_servicio.png', TRUE);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. FUNCIÓN PARA VALIDAR MÁXIMO 5 IMÁGENES POR SERVICIO
CREATE OR REPLACE FUNCTION fn_validar_max_imagenes()
RETURNS TRIGGER AS $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM servicios_imagenes
    WHERE id_servicio = NEW.id_servicio;
    
    IF v_count >= 5 THEN
        RAISE EXCEPTION 'No se pueden agregar más de 5 imágenes por servicio';
    END IF;
    
    -- Si es la primera imagen, marcarla como principal
    IF v_count = 0 THEN
        NEW.es_principal := TRUE;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_validar_max_imagenes ON servicios_imagenes;
CREATE TRIGGER tr_validar_max_imagenes
    BEFORE INSERT ON servicios_imagenes
    FOR EACH ROW
    EXECUTE FUNCTION fn_validar_max_imagenes();

-- 5. ÍNDICES PARA MEJORAR RENDIMIENTO
CREATE INDEX IF NOT EXISTS idx_servicios_categoria ON servicios(id_categoria);
CREATE INDEX IF NOT EXISTS idx_servicios_ubicacion ON servicios(ubicacion_lat, ubicacion_lng) WHERE ubicacion_lat IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_solicitudes_campos ON solicitudes USING GIN(campos_personalizados);


-- ===================================================
-- ARCHIVO: 08_Optimizacion_Indices.sql
-- ===================================================

-- =====================================================
-- OPTIMIZACIÓN: Índices y mejoras de rendimiento
-- Fecha: 2026-05-20
-- =====================================================
-- Este archivo agrega índices estratégicos para acelerar
-- las consultas más frecuentes sin alterar la estructura.
-- SAFE: No modifica datos, solo agrega índices.
-- =====================================================

-- =====================================================
-- 1. ÍNDICES PARA SOLICITUDES (consultas por estado y usuario)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_solicitudes_estado 
    ON solicitudes(estado) 
    WHERE estado IN ('Pendiente', 'Aceptada');

CREATE INDEX IF NOT EXISTS idx_solicitudes_cliente 
    ON solicitudes(id_cliente, estado);

CREATE INDEX IF NOT EXISTS idx_solicitudes_proveedor 
    ON solicitudes(id_proveedor, estado);

CREATE INDEX IF NOT EXISTS idx_solicitudes_servicio 
    ON solicitudes(id_servicio, estado);

-- =====================================================
-- 2. ÍNDICES PARA CALIFICACIONES (consultas por servicio)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_calificaciones_servicio 
    ON calificaciones(id_servicio);

CREATE INDEX IF NOT EXISTS idx_calificaciones_cliente_servicio 
    ON calificaciones(id_cliente, id_servicio);

CREATE INDEX IF NOT EXISTS idx_calificaciones_fecha 
    ON calificaciones(fecha_calificacion DESC);

-- =====================================================
-- 3. ÍNDICES PARA SERVICIOS (búsquedas y filtros)
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_servicios_proveedor 
    ON servicios(id_proveedor);

CREATE INDEX IF NOT EXISTS idx_servicios_categoria_disponible 
    ON servicios(id_categoria, disponibilidad) 
    WHERE disponibilidad > 0;

CREATE INDEX IF NOT EXISTS idx_servicios_fecha_pub 
    ON servicios(fecha_publicacion DESC);

-- Índice compuesto para búsqueda por categoría + fecha (usado en el home)
CREATE INDEX IF NOT EXISTS idx_servicios_categoria_fecha 
    ON servicios(id_categoria, fecha_publicacion DESC);

-- =====================================================
-- 4. ÍNDICES PARA SEGUIDORES (toggle y listas)
-- =====================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_seguidores_unique 
    ON seguidores(id_seguidor, id_seguido);

CREATE INDEX IF NOT EXISTS idx_seguidores_seguido 
    ON seguidores(id_seguido);

CREATE INDEX IF NOT EXISTS idx_seguidores_seguidor 
    ON seguidores(id_seguidor);

-- =====================================================
-- 5. ÍNDICES PARA USUARIOS (búsqueda por correo)
-- =====================================================
CREATE UNIQUE INDEX IF NOT EXISTS idx_usuarios_correo_unique 
    ON usuarios(correo);

-- =====================================================
-- 6. ÍNDICES PARA SERVICIOS_IMAGENES
-- =====================================================
CREATE INDEX IF NOT EXISTS idx_servicios_imagenes_servicio 
    ON servicios_imagenes(id_servicio, fecha_subida);

-- =====================================================
-- 7. FUNCIÓN OPTIMIZADA: sp_ObtenerPerfilCompleto
-- Usa JOINs en lugar de subqueries separadas
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ObtenerPerfilCompleto(
    p_id_usuario INT
)
RETURNS TABLE(
    id_usuario INT,
    nombre VARCHAR,
    descripcion TEXT,
    correo VARCHAR,
    estado BOOLEAN,
    fecha_registro TIMESTAMP,
    universidad VARCHAR,
    avatar VARCHAR,
    total_seguidores BIGINT,
    total_siguiendo BIGINT,
    total_publicaciones BIGINT,
    reputacion VARCHAR,
    total_calificaciones BIGINT
) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        RAISE EXCEPTION 'Usuario no encontrado.';
    END IF;

    RETURN QUERY
    SELECT 
        u.id_usuario,
        u.nombre,
        u.descripcion,
        u.correo,
        u.estado,
        u.fecha_registro,
        u.universidad,
        u.avatar,
        COALESCE(stats.total_seguidores, 0) AS total_seguidores,
        COALESCE(stats.total_siguiendo, 0) AS total_siguiendo,
        COALESCE(stats.total_publicaciones, 0) AS total_publicaciones,
        COALESCE(stats.reputacion, 'N/A') AS reputacion,
        COALESCE(stats.total_calificaciones, 0) AS total_calificaciones
    FROM usuarios u
    LEFT JOIN LATERAL (
        SELECT 
            (SELECT COUNT(*) FROM seguidores WHERE id_seguido = p_id_usuario) AS total_seguidores,
            (SELECT COUNT(*) FROM seguidores WHERE id_seguidor = p_id_usuario) AS total_siguiendo,
            (SELECT COUNT(*) FROM servicios WHERE id_proveedor = p_id_usuario) AS total_publicaciones,
            COUNT(c.id_calificacion) AS total_calificaciones,
            COALESCE(CAST(AVG(CAST(c.puntuacion AS DECIMAL(3,1))) AS VARCHAR(10)), 'N/A') AS reputacion
        FROM servicios s
        LEFT JOIN calificaciones c ON c.id_servicio = s.id_servicio
        WHERE s.id_proveedor = p_id_usuario
    ) stats ON true
    WHERE u.id_usuario = p_id_usuario;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. FUNCIÓN OPTIMIZADA: sp_ObtenerUsuarioPorId
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ObtenerUsuarioPorId(
    p_id_usuario INT
)
RETURNS TABLE(
    id_usuario INT,
    telefono VARCHAR,
    password_hash VARCHAR,
    nombre VARCHAR,
    descripcion TEXT,
    correo VARCHAR,
    estado BOOLEAN,
    fecha_registro TIMESTAMP,
    universidad VARCHAR,
    avatar VARCHAR
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.id_usuario,
        u.telefono,
        u.password_hash,
        u.nombre,
        u.descripcion,
        u.correo,
        u.estado,
        u.fecha_registro,
        u.universidad,
        u.avatar
    FROM usuarios u
    WHERE u.id_usuario = p_id_usuario;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Usuario no encontrado.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 9. FUNCIÓN: Obtener servicios con paginación y filtros
-- Nueva función optimizada para el endpoint GET /api/services
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ObtenerServiciosPaginados(
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 8,
    p_categoria INT DEFAULT NULL,
    p_busqueda TEXT DEFAULT NULL,
    p_orden TEXT DEFAULT 'recientes'
)
RETURNS TABLE(
    id_servicio INT,
    id_proveedor INT,
    titulo VARCHAR,
    descripcion TEXT,
    precio_hora DECIMAL,
    icono VARCHAR,
    fecha_publicacion TIMESTAMP,
    modalidad INT,
    disponibilidad INT,
    nombre_categoria VARCHAR,
    proveedor VARCHAR,
    universidad VARCHAR,
    num_resenas BIGINT,
    promedio_estrellas DOUBLE PRECISION,
    total_results BIGINT
) AS $$
DECLARE
    v_offset INT;
    v_busqueda TEXT;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    v_busqueda := LOWER(COALESCE(p_busqueda, ''));
    
    RETURN QUERY
    WITH servicios_filtrados AS (
        SELECT 
            s.id_servicio,
            s.id_proveedor,
            s.titulo,
            s.descripcion,
            s.precio_hora,
            s.icono,
            s.fecha_publicacion,
            s.modalidad,
            s.disponibilidad,
            c.nombre_categoria,
            u.nombre AS proveedor,
            u.universidad
        FROM servicios s
        LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
        LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
        WHERE (p_categoria IS NULL OR s.id_categoria = p_categoria)
          AND s.disponibilidad >= 0
          AND (
              v_busqueda = ''
              OR LOWER(s.titulo) LIKE '%' || v_busqueda || '%'
              OR LOWER(s.descripcion) LIKE '%' || v_busqueda || '%'
              OR LOWER(c.nombre_categoria) LIKE '%' || v_busqueda || '%'
              OR LOWER(u.nombre) LIKE '%' || v_busqueda || '%'
          )
    ),
    stats AS (
        SELECT 
            sf.*,
            COUNT(cal.id_calificacion) AS num_resenas,
            COALESCE(AVG(CAST(cal.puntuacion AS DOUBLE PRECISION)), 0) AS promedio_estrellas
        FROM servicios_filtrados sf
        LEFT JOIN calificaciones cal ON cal.id_servicio = sf.id_servicio
        GROUP BY 
            sf.id_servicio, sf.id_proveedor, sf.titulo, sf.descripcion,
            sf.precio_hora, sf.icono, sf.fecha_publicacion, sf.modalidad,
            sf.disponibilidad, sf.nombre_categoria, sf.proveedor, sf.universidad
    ),
    total AS (
        SELECT COUNT(*) AS cnt FROM stats
    ),
    ordenados AS (
        SELECT *, (SELECT cnt FROM total) AS total_results
        FROM stats
        ORDER BY 
            CASE WHEN p_orden = 'recientes' THEN stats.fecha_publicacion END DESC,
            CASE WHEN p_orden = 'antiguos' THEN stats.fecha_publicacion END ASC,
            CASE WHEN p_orden = 'precio-menor' THEN stats.precio_hora END ASC,
            CASE WHEN p_orden = 'precio-mayor' THEN stats.precio_hora END DESC,
            CASE WHEN p_orden = 'rating-mayor' THEN stats.promedio_estrellas END DESC,
            CASE WHEN p_orden = 'rating-menor' THEN stats.promedio_estrellas END ASC
        LIMIT p_page_size
        OFFSET v_offset
    )
    SELECT * FROM ordenados;
END;
$$ LANGUAGE plpgsql;


-- ===================================================
-- ARCHIVO: 09_Reportes_Usuarios.sql
-- ===================================================

-- ════════════════════════════════════════════════════════════════
-- Tabla de Reportes de Usuarios
-- Permite reportar: servicios fraudulentos, bugs, quejas, usuarios, etc.
-- Ejecutar en Supabase SQL Editor
-- ════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS reportes (
    id_reporte            SERIAL PRIMARY KEY,
    id_usuario            INT NOT NULL,
    id_servicio           INT,
    id_solicitud          INT,
    id_usuario_reportado  INT REFERENCES usuarios(id_usuario) ON DELETE SET NULL,
    tipo_reporte          VARCHAR(30) NOT NULL,
    titulo                VARCHAR(150) NOT NULL,
    descripcion           TEXT NOT NULL,
    evidencia             TEXT,
    estado                VARCHAR(20) DEFAULT 'Pendiente',
    fecha_creacion        TIMESTAMP DEFAULT NOW(),
    fecha_resolucion      TIMESTAMP,
    resolucion_notas      TEXT,
    id_admin_responde     INT,

    CONSTRAINT fk_reporte_usuario FOREIGN KEY (id_usuario) REFERENCES usuarios(id_usuario) ON DELETE CASCADE,
    CONSTRAINT fk_reporte_servicio FOREIGN KEY (id_servicio) REFERENCES servicios(id_servicio) ON DELETE SET NULL,
    CONSTRAINT fk_reporte_solicitud FOREIGN KEY (id_solicitud) REFERENCES solicitudes(id_solicitud) ON DELETE SET NULL,
    CONSTRAINT fk_reporte_admin FOREIGN KEY (id_admin_responde) REFERENCES usuarios(id_usuario) ON DELETE SET NULL,

    CONSTRAINT chk_tipo_reporte CHECK (tipo_reporte IN (
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
    )),

    CONSTRAINT chk_estado CHECK (estado IN ('Pendiente', 'En_revision', 'Resuelto', 'Rechazado', 'Cerrado'))
);

-- Índices para consultas frecuentes
CREATE INDEX IF NOT EXISTS idx_reportes_usuario ON reportes(id_usuario, fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS idx_reportes_estado ON reportes(estado, fecha_creacion DESC);
CREATE INDEX IF NOT EXISTS idx_reportes_servicio ON reportes(id_servicio);
CREATE INDEX IF NOT EXISTS idx_reportes_tipo ON reportes(tipo_reporte, estado);
CREATE INDEX IF NOT EXISTS idx_reportes_usuario_reportado ON reportes(id_usuario_reportado);

-- ════════════════════════════════════════════════════════════════
-- Descripciones de tipos de reporte (para referencia del frontend)
-- ════════════════════════════════════════════════════════════════
-- servicio_fraude       → Servicio falso, estafa, no cumple lo prometido
-- servicio_inapropiado  → Contenido ofensivo, ilegal o fuera de la plataforma
-- contenido_inapropiado → Imágenes, mensajes o datos inapropiados
-- pago_problema         → Problemas con pagos, cobros indebidos
-- usuario_acoso         → Acoso, amenazas, comportamiento abusivo
-- usuario_fraude        → Perfil falso, suplantación de identidad
-- usuario_abuso         → Abuso de la plataforma, explotación de vulnerabilidades
-- usuario_spam          → Envío masivo de mensajes, publicidad no solicitada
-- usuario_suplantacion  → Se hace pasar por otra persona o entidad
-- usuario_comportamiento → Comportamiento inapropiado, lenguaje ofensivo, discriminación
-- bug_tecnico           → Error de la plataforma, funcionalidad rota
-- queja_general         → Insatisfacción con el servicio recibido
-- sugerencia            → Propuesta de mejora para la plataforma
-- otro                  → Cualquier otro tipo de reporte


-- ===================================================
-- ARCHIVO: 10_Migracion_Reportes_Usuarios.sql
-- ===================================================

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


-- ===================================================
-- ARCHIVO: FIX_ambiguedad.sql
-- ===================================================

-- FIX RÁPIDO: Corregir ambigüedad en sp_ObtenerServiciosPaginados
-- Ejecutar en Supabase SQL Editor

CREATE OR REPLACE FUNCTION sp_ObtenerServiciosPaginados(
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 8,
    p_categoria INT DEFAULT NULL,
    p_busqueda TEXT DEFAULT NULL,
    p_orden TEXT DEFAULT 'recientes'
)
RETURNS TABLE(
    id_servicio INT,
    id_proveedor INT,
    titulo VARCHAR,
    descripcion TEXT,
    precio_hora DECIMAL,
    icono VARCHAR,
    fecha_publicacion TIMESTAMP,
    modalidad INT,
    disponibilidad INT,
    nombre_categoria VARCHAR,
    proveedor VARCHAR,
    universidad VARCHAR,
    num_resenas BIGINT,
    promedio_estrellas DOUBLE PRECISION,
    total_results BIGINT
) AS $$
DECLARE
    v_offset INT;
    v_busqueda TEXT;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    v_busqueda := LOWER(COALESCE(p_busqueda, ''));
    
    RETURN QUERY
    WITH servicios_filtrados AS (
        SELECT 
            s.id_servicio,
            s.id_proveedor,
            s.titulo,
            s.descripcion,
            s.precio_hora,
            s.icono,
            s.fecha_publicacion,
            s.modalidad,
            s.disponibilidad,
            c.nombre_categoria,
            u.nombre AS proveedor,
            u.universidad
        FROM servicios s
        LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
        LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
        WHERE (p_categoria IS NULL OR s.id_categoria = p_categoria)
          AND (
              v_busqueda = ''
              OR LOWER(s.titulo) LIKE '%' || v_busqueda || '%'
              OR LOWER(s.descripcion) LIKE '%' || v_busqueda || '%'
              OR LOWER(c.nombre_categoria) LIKE '%' || v_busqueda || '%'
              OR LOWER(u.nombre) LIKE '%' || v_busqueda || '%'
          )
    ),
    stats AS (
        SELECT 
            sf.id_servicio,
            sf.id_proveedor,
            sf.titulo,
            sf.descripcion,
            sf.precio_hora,
            sf.icono,
            sf.fecha_publicacion,
            sf.modalidad,
            sf.disponibilidad,
            sf.nombre_categoria,
            sf.proveedor,
            sf.universidad,
            COUNT(cal.id_calificacion) AS num_resenas,
            COALESCE(AVG(CAST(cal.puntuacion AS DOUBLE PRECISION)), 0) AS promedio_estrellas
        FROM servicios_filtrados sf
        LEFT JOIN calificaciones cal ON cal.id_servicio = sf.id_servicio
        GROUP BY 
            sf.id_servicio, sf.id_proveedor, sf.titulo, sf.descripcion,
            sf.precio_hora, sf.icono, sf.fecha_publicacion, sf.modalidad,
            sf.disponibilidad, sf.nombre_categoria, sf.proveedor, sf.universidad
    ),
    total AS (
        SELECT COUNT(*) AS cnt FROM stats
    ),
    ordenados AS (
        SELECT 
            s.*,
            (SELECT cnt FROM total) AS total_results
        FROM stats s
        ORDER BY 
            CASE WHEN p_orden = 'recientes' THEN s.fecha_publicacion END DESC,
            CASE WHEN p_orden = 'antiguos' THEN s.fecha_publicacion END ASC,
            CASE WHEN p_orden = 'precio-menor' THEN s.precio_hora END ASC,
            CASE WHEN p_orden = 'precio-mayor' THEN s.precio_hora END DESC,
            CASE WHEN p_orden = 'rating-mayor' THEN s.promedio_estrellas END DESC,
            CASE WHEN p_orden = 'rating-menor' THEN s.promedio_estrellas END ASC
        LIMIT p_page_size
        OFFSET v_offset
    )
    SELECT * FROM ordenados;
END;
$$ LANGUAGE plpgsql;


-- ===================================================
-- ARCHIVO: FIX_filtrar_pendientes.sql
-- ===================================================

-- FIX: Filtrar servicios pendientes del listado público
-- Ejecutar en Supabase SQL Editor

CREATE OR REPLACE FUNCTION sp_ObtenerServiciosPaginados(
    p_page INT DEFAULT 1,
    p_page_size INT DEFAULT 8,
    p_categoria INT DEFAULT NULL,
    p_busqueda TEXT DEFAULT NULL,
    p_orden TEXT DEFAULT 'recientes'
)
RETURNS TABLE(
    id_servicio INT,
    id_proveedor INT,
    titulo VARCHAR,
    descripcion TEXT,
    precio_hora DECIMAL,
    icono VARCHAR,
    fecha_publicacion TIMESTAMP,
    modalidad INT,
    disponibilidad INT,
    nombre_categoria VARCHAR,
    proveedor VARCHAR,
    universidad VARCHAR,
    num_resenas BIGINT,
    promedio_estrellas DOUBLE PRECISION,
    total_results BIGINT
) AS $$
DECLARE
    v_offset INT;
    v_busqueda TEXT;
BEGIN
    v_offset := (p_page - 1) * p_page_size;
    v_busqueda := LOWER(COALESCE(p_busqueda, ''));
    
    RETURN QUERY
    WITH servicios_filtrados AS (
        SELECT 
            s.id_servicio,
            s.id_proveedor,
            s.titulo,
            s.descripcion,
            s.precio_hora,
            s.icono,
            s.fecha_publicacion,
            s.modalidad,
            s.disponibilidad,
            c.nombre_categoria,
            u.nombre AS proveedor,
            u.universidad
        FROM servicios s
        LEFT JOIN usuarios u ON s.id_proveedor = u.id_usuario
        LEFT JOIN categorias c ON s.id_categoria = c.id_categoria
        WHERE (p_categoria IS NULL OR s.id_categoria = p_categoria)
          AND s.disponibilidad >= 0
          AND (
              v_busqueda = ''
              OR LOWER(s.titulo) LIKE '%' || v_busqueda || '%'
              OR LOWER(s.descripcion) LIKE '%' || v_busqueda || '%'
              OR LOWER(c.nombre_categoria) LIKE '%' || v_busqueda || '%'
              OR LOWER(u.nombre) LIKE '%' || v_busqueda || '%'
          )
    ),
    stats AS (
        SELECT 
            sf.*,
            COUNT(cal.id_calificacion) AS num_resenas,
            COALESCE(AVG(CAST(cal.puntuacion AS DOUBLE PRECISION)), 0) AS promedio_estrellas
        FROM servicios_filtrados sf
        LEFT JOIN calificaciones cal ON cal.id_servicio = sf.id_servicio
        GROUP BY 
            sf.id_servicio, sf.id_proveedor, sf.titulo, sf.descripcion,
            sf.precio_hora, sf.icono, sf.fecha_publicacion, sf.modalidad,
            sf.disponibilidad, sf.nombre_categoria, sf.proveedor, sf.universidad
    ),
    total AS (
        SELECT COUNT(*) AS cnt FROM stats
    ),
    ordenados AS (
        SELECT *, (SELECT cnt FROM total) AS total_results
        FROM stats
        ORDER BY 
            CASE WHEN p_orden = 'recientes' THEN stats.fecha_publicacion END DESC,
            CASE WHEN p_orden = 'antiguos' THEN stats.fecha_publicacion END ASC,
            CASE WHEN p_orden = 'precio-menor' THEN stats.precio_hora END ASC,
            CASE WHEN p_orden = 'precio-mayor' THEN stats.precio_hora END DESC,
            CASE WHEN p_orden = 'mejor-valorados' THEN stats.promedio_estrellas END DESC,
            stats.fecha_publicacion DESC
    )
    SELECT 
        o.id_servicio,
        o.id_proveedor,
        o.titulo,
        o.descripcion,
        o.precio_hora,
        o.icono,
        o.fecha_publicacion,
        o.modalidad,
        o.disponibilidad,
        o.nombre_categoria,
        o.proveedor,
        o.universidad,
        o.num_resenas,
        o.promedio_estrellas,
        o.total_results
    FROM ordenados o
    LIMIT p_page_size
    OFFSET v_offset;
END;
$$ LANGUAGE plpgsql;


-- ===================================================
-- ARCHIVO: fix_supabase_functions.sql
-- ===================================================

-- =====================================================
-- SUPABASE: Funciones actualizadas con ubicación y campos personalizados
-- =====================================================

-- =====================================================
-- 1. FUNCTION: Crear Servicio (sp_CrearServicio) - ACTUALIZADA
-- =====================================================
CREATE OR REPLACE FUNCTION sp_CrearServicio(
    p_id_proveedor INT,
    p_titulo VARCHAR(100),
    p_descripcion TEXT,
    p_id_categoria INT,
    p_precio_hora DECIMAL(10, 2),
    p_contacto VARCHAR(150),
    p_modalidad INT,
    p_disponibilidad INT,
    p_icono VARCHAR(10),
    p_ubicacion_lat DECIMAL(10, 8) DEFAULT NULL,
    p_ubicacion_lng DECIMAL(11, 8) DEFAULT NULL,
    p_direccion TEXT DEFAULT NULL
)
RETURNS TABLE(nuevo_servicio_id INT) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_proveedor) THEN
        RAISE EXCEPTION 'El proveedor especificado no existe.';
    END IF;

    BEGIN
        INSERT INTO servicios (
            id_proveedor, titulo, descripcion, id_categoria, precio_hora, contacto, 
            modalidad, disponibilidad, icono, ubicacion_lat, ubicacion_lng, direccion
        )
        VALUES (
            p_id_proveedor, p_titulo, p_descripcion, p_id_categoria, p_precio_hora, p_contacto, 
            p_modalidad, p_disponibilidad, p_icono, p_ubicacion_lat, p_ubicacion_lng, p_direccion
        )
        RETURNING servicios.id_servicio INTO nuevo_servicio_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FUNCTION: Gestionar Solicitud (sp_GestionarSolicitud) - ACTUALIZADA
-- =====================================================
CREATE OR REPLACE FUNCTION sp_GestionarSolicitud(
    p_id_cliente INT,
    p_id_proveedor INT,
    p_id_servicio INT,
    p_tipo_servicio VARCHAR(100),
    p_tema VARCHAR(150),
    p_descripcion TEXT,
    p_fecha_deseada DATE,
    p_hora_deseada TIME,
    p_duracion VARCHAR(50),
    p_modalidad VARCHAR(50),
    p_metodo_pago VARCHAR(50),
    p_presupuesto DECIMAL(10,2),
    p_urgencia VARCHAR(20),
    p_pago_anticipado BOOLEAN DEFAULT FALSE,
    p_archivo VARCHAR(255) DEFAULT NULL,
    p_campos_personalizados JSONB DEFAULT '{}'
)
RETURNS TABLE(Resultado VARCHAR, id_solicitud INT) AS $$
BEGIN
    IF p_id_cliente = p_id_proveedor THEN
        RAISE EXCEPTION 'No puedes solicitar tu propio servicio.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM solicitudes
        WHERE id_cliente = p_id_cliente
          AND id_servicio = p_id_servicio
          AND estado = 'Pendiente'
    ) THEN
        RAISE EXCEPTION 'Ya tienes una solicitud pendiente para este servicio.';
    END IF;

    BEGIN
        INSERT INTO solicitudes (
            id_cliente, id_proveedor, id_servicio, fue_aceptada,
            tipo_servicio, tema, descripcion,
            fecha_deseada, hora_deseada, duracion, modalidad,
            metodo_pago, presupuesto, pago_anticipado,
            urgencia, archivo, estado, campos_personalizados
        )
        VALUES (
            p_id_cliente, p_id_proveedor, p_id_servicio, 0,
            p_tipo_servicio, p_tema, p_descripcion,
            p_fecha_deseada, p_hora_deseada, p_duracion, p_modalidad,
            p_metodo_pago, p_presupuesto, p_pago_anticipado,
            p_urgencia, p_archivo, 'Pendiente', p_campos_personalizados
        )
        RETURNING solicitudes.id_solicitud INTO id_solicitud;

        Resultado := 'Solicitud enviada correctamente';
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;


-- ===================================================
-- ARCHIVO: probar.sql
-- ===================================================

-- =====================================================
-- PRUEBAS Y CONSULTAS ÚTILES (PostgreSQL)
-- Corregido desde SQL Server a PostgreSQL
-- =====================================================

-- Mostrar TODAS las calificaciones y su estado de solicitud
SELECT 
    cal.id_calificacion AS "ID Calificación",
    sol.id_solicitud AS "ID Solicitud",
    cli.nombre AS "Cliente que califica",
    prov.nombre AS "Proveedor",
    s.titulo AS "Servicio",
    sol.fue_aceptada AS "Estado (0=Pendiente, 1=Aceptada)",
    cal.puntuacion AS "Puntuación",
    cal.comentario AS "Comentario",
    CASE 
        WHEN sol.fue_aceptada = 1 THEN '✓ VÁLIDO'
        ELSE '✗ VIOLACIÓN'
    END AS "Validación"
    
FROM calificaciones cal
INNER JOIN solicitudes sol ON cal.id_solicitud = sol.id_solicitud
INNER JOIN usuarios cli ON cal.id_cliente = cli.id_usuario
INNER JOIN usuarios prov ON sol.id_proveedor = prov.id_usuario
INNER JOIN servicios s ON cal.id_servicio = s.id_servicio;

-- ========================================
-- CONTAR VIOLACIONES
-- ========================================
SELECT 
    COUNT(*) AS "Calificaciones sin solicitud aceptada"
FROM calificaciones cal
INNER JOIN solicitudes sol ON cal.id_solicitud = sol.id_solicitud
WHERE sol.fue_aceptada = 0;

-- ========================================
-- SOLICITUDES ACEPTADAS (pueden tener calificación)
-- ========================================
SELECT 
    sol.id_solicitud,
    cli.nombre AS "Cliente",
    prov.nombre AS "Proveedor",
    s.titulo AS "Servicio",
    CASE 
        WHEN cal.id_calificacion IS NOT NULL THEN 'Sí - ' || cal.puntuacion || '⭐'
        ELSE 'Sin calificar'
    END AS "Calificación"
FROM solicitudes sol
INNER JOIN usuarios cli ON sol.id_cliente = cli.id_usuario
INNER JOIN usuarios prov ON sol.id_proveedor = prov.id_usuario
INNER JOIN servicios s ON sol.id_servicio = s.id_servicio
LEFT JOIN calificaciones cal ON sol.id_solicitud = cal.id_solicitud
WHERE sol.fue_aceptada = 1;

-- ========================================
-- VERIFICAR ÍNDICES EXISTENTES
-- ========================================
SELECT 
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- ========================================
-- ESTADÍSTICAS DE TABLAS
-- ========================================
SELECT 
    relname AS tabla,
    n_live_tup AS filas_vivas,
    n_dead_tup AS filas_muertas,
    last_vacuum,
    last_analyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;


-- ===================================================
-- ARCHIVO: supabase_procedures_triggers.sql
-- ===================================================

-- =====================================================
-- SUPABASE: Procedures & Triggers (PostgreSQL)
-- Convertido desde SQL Server
-- =====================================================

-- =====================================================
-- 1. FUNCTION: Crear Usuario (sp_CrearUsuario)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_CrearUsuario(
    p_correo VARCHAR(100),
    p_password_hash VARCHAR(255),
    p_nombre VARCHAR(50),
    p_telefono VARCHAR(20) DEFAULT NULL,
    p_universidad VARCHAR(50) DEFAULT 'Sin universidad'
)
RETURNS TABLE(id_usuario INT) AS $$
BEGIN
    -- Validar solo el correo
    IF EXISTS (SELECT 1 FROM usuarios WHERE correo = p_correo) THEN
        RAISE EXCEPTION 'Este correo electrónico ya se encuentra registrado.';
    END IF;

    BEGIN
        INSERT INTO usuarios (telefono, password_hash, nombre, correo, id_rol, universidad)
        VALUES (p_telefono, p_password_hash, p_nombre, p_correo, 2, p_universidad)
        RETURNING usuarios.id_usuario INTO id_usuario;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 2. FUNCTION: Toggle Seguimiento (sp_ToggleSeguimiento)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ToggleSeguimiento(
    p_id_seguidor INT,
    p_id_seguido INT
)
RETURNS TABLE(Resultado VARCHAR) AS $$
BEGIN
    IF p_id_seguidor = p_id_seguido THEN
        RAISE EXCEPTION 'Un usuario no puede seguirse a sí mismo.';
    END IF;

    IF EXISTS (SELECT 1 FROM seguidores WHERE id_seguidor = p_id_seguidor AND id_seguido = p_id_seguido) THEN
        DELETE FROM seguidores WHERE id_seguidor = p_id_seguidor AND id_seguido = p_id_seguido;
        Resultado := 'Dejado de seguir';
        RETURN NEXT;
    ELSE
        INSERT INTO seguidores (id_seguidor, id_seguido)
        VALUES (p_id_seguidor, p_id_seguido);
        Resultado := 'Siguiendo';
        RETURN NEXT;
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 3. FUNCTION: Crear Servicio (sp_CrearServicio)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_CrearServicio(
    p_id_proveedor INT,
    p_titulo VARCHAR(100),
    p_descripcion TEXT,
    p_id_categoria INT,
    p_precio_hora DECIMAL(10, 2),
    p_contacto VARCHAR(150),
    p_modalidad INT,
    p_disponibilidad INT,
    p_icono VARCHAR(10)
)
RETURNS TABLE(nuevo_servicio_id INT) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_proveedor) THEN
        RAISE EXCEPTION 'El proveedor especificado no existe.';
    END IF;

    BEGIN
        INSERT INTO servicios (id_proveedor, titulo, descripcion, id_categoria, precio_hora, contacto, modalidad, disponibilidad, icono)
        VALUES (p_id_proveedor, p_titulo, p_descripcion, p_id_categoria, p_precio_hora, p_contacto, p_modalidad, p_disponibilidad, p_icono)
        RETURNING servicios.id_servicio INTO nuevo_servicio_id;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 4. FUNCTION: Gestionar Solicitud (sp_GestionarSolicitud)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_GestionarSolicitud(
    p_id_cliente INT,
    p_id_proveedor INT,
    p_id_servicio INT,
    p_tipo_servicio VARCHAR(100),
    p_tema VARCHAR(150),
    p_descripcion TEXT,
    p_fecha_deseada DATE,
    p_hora_deseada TIME,
    p_duracion VARCHAR(50),
    p_modalidad VARCHAR(50),
    p_metodo_pago VARCHAR(50),
    p_presupuesto DECIMAL(10,2),
    p_pago_anticipado BOOLEAN DEFAULT FALSE,
    p_urgencia VARCHAR(20),
    p_archivo VARCHAR(255) DEFAULT NULL
)
RETURNS TABLE(Resultado VARCHAR, id_solicitud INT) AS $$
BEGIN
    -- Validar que no se solicite a sí mismo
    IF p_id_cliente = p_id_proveedor THEN
        RAISE EXCEPTION 'No puedes solicitar tu propio servicio.';
    END IF;

    -- Validar que no exista una solicitud pendiente
    IF EXISTS (
        SELECT 1 FROM solicitudes
        WHERE id_cliente = p_id_cliente
          AND id_servicio = p_id_servicio
          AND estado = 'Pendiente'
    ) THEN
        RAISE EXCEPTION 'Ya tienes una solicitud pendiente para este servicio.';
    END IF;

    BEGIN
        INSERT INTO solicitudes (
            id_cliente, id_proveedor, id_servicio, fue_aceptada,
            tipo_servicio, tema, descripcion,
            fecha_deseada, hora_deseada, duracion, modalidad,
            metodo_pago, presupuesto, pago_anticipado,
            urgencia, archivo, estado
        )
        VALUES (
            p_id_cliente, p_id_proveedor, p_id_servicio, 0,
            p_tipo_servicio, p_tema, p_descripcion,
            p_fecha_deseada, p_hora_deseada, p_duracion, p_modalidad,
            p_metodo_pago, p_presupuesto, p_pago_anticipado,
            p_urgencia, p_archivo, 'Pendiente'
        )
        RETURNING solicitudes.id_solicitud INTO id_solicitud;

        Resultado := 'Solicitud enviada correctamente';
        RETURN NEXT;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 5. FUNCTION: Guardar Calificacion con Aspectos (sp_GuardarCalificacionConAspectos)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_GuardarCalificacionConAspectos(
    p_id_solicitud INT,
    p_id_cliente INT,
    p_id_servicio INT,
    p_puntuacion SMALLINT,
    p_comentario TEXT,
    p_aspectos_nombres TEXT
)
RETURNS TABLE(Resultado VARCHAR) AS $$
DECLARE
    v_id_calificacion INT;
    v_aspecto TEXT;
BEGIN
    IF EXISTS (SELECT 1 FROM calificaciones WHERE id_cliente = p_id_cliente AND id_servicio = p_id_servicio) THEN
        UPDATE calificaciones 
        SET puntuacion = p_puntuacion, comentario = p_comentario, fecha_modificacion = NOW()
        WHERE id_cliente = p_id_cliente AND id_servicio = p_id_servicio;

        SELECT id_calificacion INTO v_id_calificacion
        FROM calificaciones
        WHERE id_cliente = p_id_cliente AND id_servicio = p_id_servicio;

        DELETE FROM aspectos_destacados WHERE id_calificacion = v_id_calificacion;
    ELSE
        INSERT INTO calificaciones (id_solicitud, id_cliente, id_servicio, puntuacion, comentario)
        VALUES (p_id_solicitud, p_id_cliente, p_id_servicio, p_puntuacion, p_comentario)
        RETURNING id_calificacion INTO v_id_calificacion;
    END IF;

    -- Insertar aspectos (simula STRING_SPLIT)
    FOREACH v_aspecto IN ARRAY string_to_array(p_aspectos_nombres, ',') LOOP
        INSERT INTO aspectos_destacados (id_calificacion, tipo_aspecto)
        VALUES (v_id_calificacion, trim(v_aspecto));
    END LOOP;

    Resultado := 'Calificación procesada correctamente';
    RETURN NEXT;
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '%', SQLERRM;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 6. FUNCTION: Actualizar Usuario (sp_ActualizarUsuario)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ActualizarUsuario(
    p_id_usuario INT,
    p_telefono VARCHAR(13) DEFAULT NULL,
    p_password_hash VARCHAR(255) DEFAULT NULL,
    p_nombre VARCHAR(50) DEFAULT NULL,
    p_descripcion TEXT DEFAULT NULL,
    p_correo VARCHAR(100) DEFAULT NULL,
    p_estado BOOLEAN DEFAULT NULL,
    p_bloqueado BOOLEAN DEFAULT NULL,
    p_universidad VARCHAR(50) DEFAULT NULL,
    p_avatar VARCHAR(255) DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    -- Validar si el usuario existe
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        RAISE EXCEPTION 'El usuario con el ID proporcionado no existe.';
    END IF;

    -- Validar duplicidad de correo
    IF p_correo IS NOT NULL AND EXISTS (
        SELECT 1 FROM usuarios WHERE correo = p_correo AND id_usuario <> p_id_usuario
    ) THEN
        RAISE EXCEPTION 'El nuevo correo electrónico ya está registrado por otro usuario.';
    END IF;

    BEGIN
        UPDATE usuarios
        SET 
            telefono      = COALESCE(p_telefono, telefono),
            password_hash = COALESCE(p_password_hash, password_hash),
            nombre        = COALESCE(p_nombre, nombre),
            descripcion   = COALESCE(p_descripcion, descripcion),
            correo        = COALESCE(p_correo, correo),
            estado        = COALESCE(p_estado, estado),
            bloqueado     = COALESCE(p_bloqueado, bloqueado),
            universidad   = COALESCE(p_universidad, universidad),
            avatar        = COALESCE(p_avatar, avatar)
        WHERE id_usuario = p_id_usuario;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'No se pudo actualizar el usuario. Verifique los datos proporcionados.';
        END IF;
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '%', SQLERRM;
    END;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 7. FUNCTION: Obtener Usuario Por Id (sp_ObtenerUsuarioPorId)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ObtenerUsuarioPorId(
    p_id_usuario INT
)
RETURNS TABLE(
    id_usuario INT,
    telefono VARCHAR,
    password_hash VARCHAR,
    nombre VARCHAR,
    descripcion TEXT,
    correo VARCHAR,
    estado BOOLEAN,
    fecha_registro TIMESTAMP,
    universidad VARCHAR,
    avatar VARCHAR
) AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        RETURN QUERY
        SELECT 
            u.id_usuario,
            u.telefono,
            u.password_hash,
            u.nombre,
            u.descripcion,
            u.correo,
            u.estado,
            u.fecha_registro,
            u.universidad,
            u.avatar
        FROM usuarios u
        WHERE u.id_usuario = p_id_usuario;
    ELSE
        RAISE EXCEPTION 'Usuario no encontrado.';
    END IF;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 8. FUNCTION: Obtener Perfil Completo (sp_ObtenerPerfilCompleto)
-- =====================================================
CREATE OR REPLACE FUNCTION sp_ObtenerPerfilCompleto(
    p_id_usuario INT
)
RETURNS TABLE(
    id_usuario INT,
    nombre VARCHAR,
    descripcion TEXT,
    correo VARCHAR,
    estado BOOLEAN,
    fecha_registro TIMESTAMP,
    universidad VARCHAR,
    avatar VARCHAR,
    total_seguidores BIGINT,
    total_siguiendo BIGINT,
    total_publicaciones BIGINT,
    reputacion VARCHAR,
    total_calificaciones BIGINT
) AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM usuarios WHERE id_usuario = p_id_usuario) THEN
        RAISE EXCEPTION 'Usuario no encontrado.';
    END IF;

    RETURN QUERY
    SELECT 
        u.id_usuario,
        u.nombre,
        u.descripcion,
        u.correo,
        u.estado,
        u.fecha_registro,
        u.universidad,
        u.avatar,
        (SELECT COUNT(*) FROM seguidores WHERE id_seguido = p_id_usuario) AS total_seguidores,
        (SELECT COUNT(*) FROM seguidores WHERE id_seguidor = p_id_usuario) AS total_siguiendo,
        (SELECT COUNT(*) FROM servicios WHERE id_proveedor = p_id_usuario) AS total_publicaciones,
        COALESCE(CAST(AVG(CAST(c.puntuacion AS DECIMAL(3,1))) AS VARCHAR(10)), 'N/A') AS reputacion,
        COUNT(c.id_calificacion) AS total_calificaciones
    FROM usuarios u
        LEFT JOIN servicios s ON s.id_proveedor = u.id_usuario
        LEFT JOIN calificaciones c ON c.id_servicio = s.id_servicio
    WHERE u.id_usuario = p_id_usuario
    GROUP BY u.id_usuario, u.nombre, u.descripcion, u.correo, u.estado, u.fecha_registro, u.universidad, u.avatar;
END;
$$ LANGUAGE plpgsql;

-- =====================================================
-- 9. TRIGGER: Asignación automática de imagen default al crear servicio
-- =====================================================

-- Función del trigger
CREATE OR REPLACE FUNCTION fn_servicio_asignar_imagen_default()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO servicios_imagenes (id_servicio, url_imagen, es_principal)
    VALUES (NEW.id_servicio, 'img/default_servicio.png', TRUE);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Crear el trigger
DROP TRIGGER IF EXISTS tr_servicio_asignar_imagen_default ON servicios;
CREATE TRIGGER tr_servicio_asignar_imagen_default
    AFTER INSERT ON servicios
    FOR EACH ROW
    EXECUTE FUNCTION fn_servicio_asignar_imagen_default();


-- ===================================================
-- ARCHIVO: supabase_seed_data.sql
-- ===================================================

-- =====================================================
-- SUPABASE: Datos de prueba (PostgreSQL)
-- Copiar y pegar TODO en el SQL Editor de Supabase
-- =====================================================

-- Limpiar datos existentes (en orden inverso a las FK)
DELETE FROM aspectos_destacados;
DELETE FROM calificaciones;
DELETE FROM solicitudes;
DELETE FROM servicios_imagenes;
DELETE FROM servicios;
DELETE FROM seguidores;
DELETE FROM usuarios;
DELETE FROM categorias;
DELETE FROM rol_usuarios;

-- Resetear secuencias
ALTER SEQUENCE rol_usuarios_id_rol_seq RESTART WITH 1;
ALTER SEQUENCE usuarios_id_usuario_seq RESTART WITH 1;
ALTER SEQUENCE categorias_id_categoria_seq RESTART WITH 1;
ALTER SEQUENCE servicios_id_servicio_seq RESTART WITH 1;
ALTER SEQUENCE solicitudes_id_solicitud_seq RESTART WITH 1;
ALTER SEQUENCE calificaciones_id_calificacion_seq RESTART WITH 1;

-- 1. ROLES
INSERT INTO rol_usuarios (nombre_rol) VALUES
    ('Administrador'),
    ('Usuario comun');

-- 2. USUARIOS (contraseña: 123456789 para todos)
INSERT INTO usuarios (telefono, password_hash, nombre, descripcion, correo, id_rol, universidad) VALUES
    ('3117906271', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'UniService', 'Administrador del sistema', 'uniservice.soporte@gmail.com', 1, 'Sin universidad'),
    ('3043307911', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sayd', 'Estudiante de Ingenieria de Sistemas UPC', 'barrerasayd7@gmail.com', 2, 'Universidad Popular del Cesar'),
    ('3001234567', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Camilo', 'Estudiante de Ingenieria de Sistemas', 'camilo.sist@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3012345678', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Valentina', 'Estudiante de Derecho Septimo Semestre', 'valen_upc@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3109876543', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Andres', 'Monitor de Matematicas y Fisica', 'andres_monitor@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3156789012', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Mariana', 'Apasionada por programacion en Python y React', 'mariana_dev@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3204567890', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Mateo', 'Estudiante de Contaduria Publica', 'mateo.contable@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3009998877', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Daniela', 'Lider del grupo de investigacion de software', 'daniela_inv@gmail.com', 2, 'Sin universidad'),
    ('3112223344', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sebastian', 'Estudiante de Ing. Electronica', 'sebas_elec@gmail.com', 2, 'Sin universidad'),
    ('3183334455', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Paula', 'Estudiante de Psicologia UPC', 'paula.psi@gmail.com', 2, 'Sin universidad'),
    ('3045556677', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Santiago', 'Interesado en redes y ciberseguridad', 'santiago_net@gmail.com', 2, 'Sin universidad'),
    ('3127778899', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Gabriela', 'Estudiante de Licenciatura en Idiomas', 'gabi.languages@gmail.com', 2, 'Sin universidad'),
    ('3162223344', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Julian', 'Especialista en bases de datos SQL', 'julian.sql@gmail.com', 2, 'Sin universidad'),
    ('3174445566', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Elena', 'Estudiante de Ingenieria Ambiental', 'elena_ambiental@gmail.com', 2, 'Sin universidad'),
    ('3028889900', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Diego', 'Entusiasta de la IA y el Machine Learning', 'diego_ia@gmail.com', 2, 'Sin universidad'),
    ('3136667788', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Sara', 'Estudiante de Economia', 'sara_econ@gmail.com', 2, 'Sin universidad'),
    ('3005554433', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Felipe', 'Desarrollador backend junior', 'felipe_back@gmail.com', 2, 'Universidad Pontificia Comillas'),
    ('3141110099', '$2y$10$n.QB9K1ni2zC/zjJGKcfaufpqQjeAE8Nx.gbW/U36aRyjFqecG7RO', 'Lucia', 'Estudiante de Sociologia', 'lucia_soc@gmail.com', 2, 'Sin universidad');

-- 3. CATEGORÍAS
INSERT INTO categorias (nombre_categoria) VALUES
    ('Tutorías'),
    ('Ensayos y redacción'),
    ('Proyectos'),
    ('Programación'),
    ('Diseño'),
    ('Arriendo de habitaciones'),
    ('Otros servicios');

-- 4. SEGUIDORES
INSERT INTO seguidores (id_seguidor, id_seguido) VALUES
    (1, 3), (3, 1),
    (2, 4), (4, 2),
    (3, 5), (5, 3),
    (4, 6), (6, 4),
    (1, 13), (13, 1),
    (13, 11), (11, 13),
    (15, 1), (1, 15),
    (17, 3), (3, 17),
    (8, 10), (10, 8),
    (10, 12), (12, 10),
    (18, 8), (8, 18),
    (14, 17), (17, 14),
    (5, 1), (7, 2),
    (9, 4), (12, 17),
    (16, 3), (6, 11),
    (2, 15), (4, 9);

-- 5. SERVICIOS
INSERT INTO servicios (id_proveedor, titulo, descripcion, id_categoria, precio_hora, contacto, modalidad, icono, disponibilidad) VALUES
    (3, 'Bases de Datos SQL', 'Diseño de diagramas ER y consultas complejas', 4, 40000.00, '3001234567', 1, '🗄️', 1),
    (4, 'Scripts en Python', 'Automatización de tareas y análisis de datos', 4, 30000.00, '3012345678', 1, '🐍', 1),
    (11, 'App Móvil con Flutter', 'Desarrollo de prototipos para Android/iOS', 4, 120000.00, '3210001122', 1, '📱', 1),
    (13, 'Corrección de Bugs Java', 'Debug de proyectos universitarios en Java', 4, 20000.00, '3162223344', 1, '👾', 1),
    (5, 'Clases de Álgebra Lineal', 'Vectores, matrices y espacios vectoriales', 1, 15000.00, '3109876543', 0, '📐', 1),
    (8, 'Tutoría de Psicología', 'Apoyo en teorías del aprendizaje', 1, 18000.00, '3183334455', 0, '🧠', 1),
    (10, 'Clases de Inglés B1', 'Práctica de conversación y gramática', 1, 25000.00, '3127778899', 0, '🇺🇸', 1),
    (16, 'Tutoría de Microeconomía', 'Curvas de oferta, demanda y equilibrio', 1, 22000.00, '3136667788', 0, '📈', 1),
    (15, 'Tutoría de Física II', 'Termodinámica y electromagnetismo', 1, 30000.00, '3028889900', 0, '⚡', 1),
    (2, 'Corrección de Estilo APA', 'Ajuste de normas APA 7ma edición para tesis', 2, 10000.00, '3117906271', 1, '✍️', 1),
    (18, 'Redacción de Ensayos', 'Textos argumentativos sobre sociología', 2, 25000.00, '3141110099', 1, '📝', 1),
    (12, 'Traducción de Resúmenes', 'Traducción técnico-académica (Inglés/Español)', 2, 12000.00, '3051112233', 1, '🌐', 1),
    (6, 'Plan de Negocios', 'Estructuración de proyectos de emprendimiento', 3, 50000.00, '3156789012', 1, '💼', 1),
    (14, 'Asesoría Ambiental', 'Informes de impacto y gestión de residuos', 3, 45000.00, '3174445566', 1, '🌱', 1),
    (7, 'Análisis Estadístico', 'Procesamiento de datos en Excel o SPSS', 3, 35000.00, '3204567890', 1, '📊', 1),
    (9, 'Logotipos para Proyectos', 'Diseño de identidad visual para startups', 5, 60000.00, '3045556677', 1, '🎨', 1),
    (1, 'Edición de Video', 'Montaje para redes sociales y presentaciones', 5, 40000.00, '3043307911', 1, '🎬', 1),
    (4, 'Diseño de Diapositivas', 'Presentaciones interactivas en Canva', 5, 15000.00, '3012345678', 1, '✨', 1),
    (17, 'Habitación Central', 'Cerca a la UPC, incluye servicios y WiFi', 6, 450000.00, '3005554433', 0, '🏠', 1),
    (12, 'Aparto-estudio Estudiantes', 'Entrada independiente y baño privado', 6, 600000.00, '3051112233', 0, '🔑', 1),
    (5, 'Cupo Universitario', 'Habitación compartida, ambiente tranquilo', 6, 300000.00, '3109876543', 0, '🛌', 1),
    (3, 'Mantenimiento de PC', 'Limpieza física y cambio de pasta térmica', 7, 50000.00, '3001234567', 1, '🔧', 1),
    (10, 'Venta de Almuerzos', 'Comida casera con domicilio en el campus', 7, 12000.00, '3127778899', 0, '🍱', 1),
    (8, 'Asesoría Nutricional', 'Planes de alimentación para estudiantes', 7, 30000.00, '3183334455', 0, '🍎', 1),
    (15, 'Reparación de Celulares', 'Cambio de pantallas y baterías', 7, 80000.00, '3028889900', 1, '🛠️', 1),
    (6, 'Venta de Accesorios', 'Cables USB, audífonos y protectores', 7, 15000.00, '3156789012', 1, '🎧', 1),
    (13, 'Formateo de Laptops', 'Instalación de Windows y Office', 7, 45000.00, '3162223344', 1, '💿', 1),
    (11, 'Fotografía para Eventos', 'Sesiones fotográficas académicas', 7, 100000.00, '3210001122', 1, '📸', 1);

-- 6. SOLICITUDES
INSERT INTO solicitudes (id_cliente, id_proveedor, id_servicio, fue_aceptada, estado) VALUES
    (3, 11, 3, true, 'Aceptada'),
    (11, 1, 1, true, 'Aceptada'),
    (15, 13, 4, true, 'Aceptada'),
    (1, 3, 1, true, 'Aceptada'),
    (17, 4, 2, false, 'Pendiente'),
    (5, 2, 2, true, 'Aceptada'),
    (8, 10, 7, true, 'Aceptada'),
    (16, 5, 5, false, 'Pendiente'),
    (10, 16, 8, true, 'Aceptada'),
    (2, 15, 9, false, 'Pendiente'),
    (18, 2, 10, true, 'Aceptada'),
    (12, 18, 11, true, 'Aceptada'),
    (9, 4, 18, true, 'Aceptada'),
    (4, 9, 16, false, 'Pendiente'),
    (7, 1, 17, true, 'Aceptada'),
    (5, 17, 19, true, 'Aceptada'),
    (10, 12, 20, false, 'Pendiente'),
    (14, 5, 21, true, 'Aceptada'),
    (1, 10, 23, true, 'Aceptada'),
    (3, 8, 24, false, 'Pendiente'),
    (6, 15, 25, true, 'Aceptada'),
    (13, 6, 26, true, 'Aceptada'),
    (11, 13, 27, false, 'Pendiente'),
    (8, 11, 28, true, 'Aceptada'),
    (12, 3, 22, true, 'Aceptada'),
    (7, 10, 23, true, 'Aceptada'),
    (18, 12, 12, true, 'Aceptada'),
    (4, 1, 1, true, 'Aceptada');

-- 7. CALIFICACIONES
INSERT INTO calificaciones (id_solicitud, id_cliente, id_servicio, puntuacion, comentario) VALUES
    (1, 3, 3, 5, 'Excelente manejo de SQL, me salvó el proyecto de bases de datos.'),
    (2, 4, 4, 5, 'El script de Python funcionó perfecto, muy rápido.'),
    (3, 11, 3, 4, 'Muy buen diseño de interfaces, aunque demoró un poquito en la entrega.'),
    (4, 15, 4, 5, 'Encontró el error en mi código Java en 10 minutos. Recomendado.'),
    (28, 4, 1, 5, 'La interfaz en React quedó súper moderna, justo lo que buscaba.'),
    (6, 5, 2, 5, 'Explica el Cálculo Integral mucho mejor que el profesor, 10/10.'),
    (7, 8, 7, 4, 'Muy buena la clase de inglés, me ayudó mucho con la pronunciación.'),
    (9, 10, 8, 5, 'Domina totalmente el tema de microeconomía. Muy paciente.'),
    (19, 1, 23, 5, 'El almuerzo estaba delicioso y calientico, gran servicio en la U.'),
    (27, 18, 12, 4, 'La traducción técnica fue muy precisa, me sirvió para el abstract.'),
    (16, 5, 19, 5, 'La habitación es tal cual las fotos, muy cerca de la sede Sabanas.'),
    (18, 14, 21, 4, 'Ambiente muy tranquilo para estudiar, el WiFi vuela.'),
    (21, 6, 25, 3, 'Arregló el celular, pero la pantalla no quedó del todo centrada.'),
    (22, 13, 26, 5, 'Los audífonos son originales y a buen precio.'),
    (24, 8, 28, 5, 'Las fotos para mi grado quedaron increíbles, muy profesional.'),
    (11, 18, 10, 5, 'Me dejó el ensayo con normas APA perfecto, sin errores.'),
    (15, 7, 17, 4, 'Buen editor de video, entendió rápido la idea.'),
    (25, 12, 22, 5, 'Mi laptop quedó como nueva después del mantenimiento.'),
    (26, 7, 23, 5, 'Puntual con la entrega del almuerzo en la biblioteca.'),
    (5, 2, 1, 2, 'No pudimos concretar la hora, pero fue amable.'),
    (8, 16, 5, 4, 'Las clases de álgebra me ayudaron a pasar el parcial.'),
    (14, 9, 18, 4, 'Las diapositivas en Canva quedaron muy estéticas.'),
    (20, 3, 24, 3, 'La asesoría fue buena, pero un poco costosa para ser estudiante.'),
    (10, 2, 15, 5, 'Física II es difícil, pero con esta tutoría se entiende todo.'),
    (17, 10, 20, 5, 'El aparto-estudio es muy seguro y el sector es bueno.'),
    (23, 11, 27, 4, 'Formateo rápido y dejó todos los drivers instalados.'),
    (12, 1, 2, 5, 'El mejor tutor de la UPC, sin duda alguna.');

-- 8. ASPECTOS DESTACADOS
INSERT INTO aspectos_destacados (id_calificacion, tipo_aspecto) VALUES
    (1, 'Puntualidad'),
    (1, 'Calidad'),
    (1, 'Comunicación'),
    (1, 'Precio justo');


-- ===================================================
-- ARCHIVO: VERIFICAR_disponibilidad.sql
-- ===================================================

-- Verificar el estado de disponibilidad de todos los servicios
-- Ejecutar en Supabase SQL Editor

-- Ver valores de disponibilidad
SELECT id_servicio, titulo, disponibilidad, fecha_publicacion
FROM servicios
ORDER BY fecha_publicacion DESC
LIMIT 20;

-- Contar por estado
SELECT 
    CASE 
        WHEN disponibilidad = -1 THEN 'Pendiente (no debe aparecer)'
        WHEN disponibilidad = 0 THEN 'Entre semana'
        WHEN disponibilidad = 1 THEN 'Fines de semana'
        WHEN disponibilidad = 2 THEN 'Siempre disponible'
        ELSE 'Otro valor: ' || disponibilidad
    END as estado,
    COUNT(*) as cantidad
FROM servicios
GROUP BY disponibilidad
ORDER BY disponibilidad;


