-- Después de 010 y ANTES de iniciar la API actualizada.
-- Puede repetirse sin reiniciar una negociación ya existente.
BEGIN;
ALTER TABLE public.solicitudes
  ADD COLUMN IF NOT EXISTS estado_contraoferta text,
  ADD COLUMN IF NOT EXISTS version_contraoferta integer NOT NULL DEFAULT 0;

UPDATE public.solicitudes
SET estado_contraoferta = CASE WHEN estado = 'Pendiente' THEN 'pendiente' ELSE 'aceptada' END,
    version_contraoferta = 1
WHERE contraoferta IS NOT NULL AND estado_contraoferta IS NULL;

DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_constraint
      WHERE conrelid = 'public.solicitudes'::regclass AND conname = 'ck_solicitud_negociacion') THEN
    ALTER TABLE public.solicitudes ADD CONSTRAINT ck_solicitud_negociacion CHECK (
      (contraoferta IS NULL AND estado_contraoferta IS NULL AND version_contraoferta = 0)
      OR (contraoferta IS NOT NULL AND estado_contraoferta IS NOT NULL
          AND estado_contraoferta IN ('pendiente', 'aceptada', 'rechazada')
          AND version_contraoferta > 0)
    );
  END IF;
END $$;

INSERT INTO uniservice_mobile.migraciones(version)
VALUES ('011_contraofertas_solicitudes') ON CONFLICT DO NOTHING;
COMMIT;
