-- =====================================
-- Esquema de Reservas (PostgreSQL)
-- =====================================

\connect bookingdb

CREATE EXTENSION IF NOT EXISTS btree_gist;

SET ROLE bookinguser;

-- =====================================================
-- TABLA: salas
-- =====================================================
CREATE TABLE IF NOT EXISTS salas (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  capacidad INT NOT NULL CHECK (capacidad > 0),
  descripcion TEXT NULL,

  usuario_creacion_id BIGINT NULL,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  usuario_modificacion_id BIGINT NULL,
  fecha_modificacion TIMESTAMPTZ NULL,
  fecha_eliminacion TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_salas_nombre_activo
  ON salas (LOWER(nombre))
  WHERE fecha_eliminacion IS NULL;

-- =====================================================
-- TABLA: reservas
-- =====================================================
CREATE TABLE IF NOT EXISTS reservas (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

  folio VARCHAR(40) NOT NULL,
  sala_id BIGINT NOT NULL REFERENCES salas(id),
  departamento_id BIGINT NOT NULL,
  solicitante VARCHAR(120) NOT NULL,

  titulo VARCHAR(160) NULL,
  descripcion TEXT NULL,

  inicia_en TIMESTAMPTZ NOT NULL,
  termina_en TIMESTAMPTZ NOT NULL,

  estatus_id INT NOT NULL, -- 1=PENDIENTE, 2=APROBADA, 3=RECHAZADA, 4=CANCELADA
  motivo_cancelacion TEXT NULL,

  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  usuario_modificacion_id BIGINT NULL,
  fecha_modificacion TIMESTAMPTZ NULL,
  fecha_eliminacion TIMESTAMPTZ NULL,

  CHECK (termina_en > inicia_en)
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_reservas_folio_activo
  ON reservas (folio)
  WHERE fecha_eliminacion IS NULL;

CREATE INDEX IF NOT EXISTS ix_reservas_sala
  ON reservas (sala_id)
  WHERE fecha_eliminacion IS NULL;

CREATE INDEX IF NOT EXISTS ix_reservas_departamento
  ON reservas (departamento_id)
  WHERE fecha_eliminacion IS NULL;


CREATE INDEX IF NOT EXISTS ix_reservas_sala_inicia_en
  ON reservas (sala_id, inicia_en)
  WHERE fecha_eliminacion IS NULL;

-- =====================================================
-- Anti-overbooking
-- =====================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'reservas_no_traslape_por_sala'
  ) THEN
    ALTER TABLE reservas
      ADD CONSTRAINT reservas_no_traslape_por_sala
      EXCLUDE USING gist (
        sala_id WITH =,
        tstzrange(inicia_en, termina_en, '[)') WITH &&
      )
      WHERE (fecha_eliminacion IS NULL AND estatus_id IN (1,2));
  END IF;
END $$;

-- =====================================================
-- TABLA: historial_cambios_reservas
-- =====================================================
CREATE TABLE IF NOT EXISTS historial_cambios_reservas (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  reserva_id BIGINT NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,

  actor_empleado_id BIGINT NOT NULL,
  evento VARCHAR(40) NOT NULL,
  comentario TEXT NULL,

  antes JSONB NULL,
  despues JSONB NULL,

  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_historial_reserva
  ON historial_cambios_reservas (reserva_id);

-- =====================================================
-- SEED DATA
-- =====================================================

-- -------------------------
-- Salas
-- -------------------------
INSERT INTO salas (nombre, capacidad, descripcion)
VALUES
  ('Sala Ejecutiva', 12, 'Sala principal con proyector y videoconferencia'),
  ('Sala Creativa', 8, 'Espacio flexible para brainstorming'),
  ('Sala Pequeña', 4, 'Sala para reuniones rápidas')
ON CONFLICT DO NOTHING;

-- -------------------------
-- Reservas de ejemplo
-- -------------------------
INSERT INTO reservas (
  folio,
  sala_id,
  departamento_id,
  solicitante,
  titulo,
  descripcion,
  inicia_en,
  termina_en,
  estatus_id
)
VALUES
  (
    'RS-00001',
    (SELECT id FROM salas WHERE LOWER(nombre) = LOWER('Sala Ejecutiva') LIMIT 1),
    1,
    'José Perez',
    'Reunión estratégica',
    'Planeación trimestral',
    NOW() + INTERVAL '1 day',
    NOW() + INTERVAL '1 day 2 hours',
    2
  ),
  (
    'RS-00002',
    (SELECT id FROM salas WHERE LOWER(nombre) = LOWER('Sala Creativa') LIMIT 1),
    1,
    'José Perez',
    'Sprint Planning',
    'Planeación del sprint',
    NOW() + INTERVAL '2 days',
    NOW() + INTERVAL '2 days 1 hour',
    1
  );

-- -------------------------
-- Historial inicial
-- -------------------------
INSERT INTO historial_cambios_reservas (
  reserva_id,
  actor_empleado_id,
  evento,
  comentario,
  despues
)
SELECT
  r.id,
  1,
  'CREADA',
  'Reserva creada automáticamente en seed',
  to_jsonb(r)
FROM reservas r
WHERE r.folio IN ('RS-00001', 'RS-00002');

RESET ROLE;