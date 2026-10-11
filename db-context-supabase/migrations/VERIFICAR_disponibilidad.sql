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
