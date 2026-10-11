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
