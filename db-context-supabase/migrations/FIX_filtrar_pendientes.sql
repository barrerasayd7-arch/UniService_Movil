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
