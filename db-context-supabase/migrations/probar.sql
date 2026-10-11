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
