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
