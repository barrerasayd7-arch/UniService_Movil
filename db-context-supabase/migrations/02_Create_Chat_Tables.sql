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
