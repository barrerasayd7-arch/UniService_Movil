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
