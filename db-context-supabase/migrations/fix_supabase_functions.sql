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
