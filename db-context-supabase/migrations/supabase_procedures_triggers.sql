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
