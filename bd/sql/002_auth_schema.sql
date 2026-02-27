-- 002_auth_schema.sql
\connect authdb
SET ROLE authuser;

-- -------------------------
-- TABLA: departamentos
-- -------------------------
CREATE TABLE IF NOT EXISTS departamentos (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT NULL,

  usuario_creacion_id BIGINT NULL,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  usuario_modificacion_id BIGINT NULL,
  fecha_modificacion TIMESTAMPTZ NULL,
  fecha_eliminacion TIMESTAMPTZ NULL
);

-- nombre único para activos (opcional pero útil)
CREATE UNIQUE INDEX IF NOT EXISTS ux_departamentos_nombre_activo
  ON departamentos (LOWER(nombre))
  WHERE fecha_eliminacion IS NULL;

-- -------------------------
-- TABLA: puestos
-- -------------------------
CREATE TABLE IF NOT EXISTS puestos (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(120) NOT NULL,
  descripcion TEXT NULL,

  usuario_creacion_id BIGINT NULL,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  usuario_modificacion_id BIGINT NULL,
  fecha_modificacion TIMESTAMPTZ NULL,
  fecha_eliminacion TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_puestos_nombre_activo
  ON puestos (LOWER(nombre))
  WHERE fecha_eliminacion IS NULL;

-- -------------------------
-- TABLA: apps
-- -------------------------
CREATE TABLE IF NOT EXISTS apps (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  clave VARCHAR(60) NOT NULL,         -- ej: 'BOOKINGS', 'HARVESTQC'
  nombre VARCHAR(120) NOT NULL,

  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  fecha_eliminacion TIMESTAMPTZ NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS ux_apps_clave_activa
  ON apps (LOWER(clave))
  WHERE fecha_eliminacion IS NULL;

-- -------------------------
-- TABLA: empleados
-- -------------------------
CREATE TABLE IF NOT EXISTS empleados (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  correo VARCHAR(100) NOT NULL,
  contrasena_hash TEXT NOT NULL,

  puesto_id BIGINT NOT NULL REFERENCES puestos(id),
  departamento_id BIGINT NOT NULL REFERENCES departamentos(id),

  estatus_id INT NOT NULL,

  usuario_creacion_id BIGINT NULL,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  usuario_modificacion_id BIGINT NULL,
  fecha_modificacion TIMESTAMPTZ NULL,
  fecha_eliminacion TIMESTAMPTZ NULL
);

-- Correo único (case-insensitive) solo para empleados activos
CREATE UNIQUE INDEX IF NOT EXISTS ux_empleados_correo_activo
  ON empleados (LOWER(correo))
  WHERE fecha_eliminacion IS NULL;

-- Índices útiles para búsquedas comunes
CREATE INDEX IF NOT EXISTS ix_empleados_departamento
  ON empleados (departamento_id)
  WHERE fecha_eliminacion IS NULL;

CREATE INDEX IF NOT EXISTS ix_empleados_puesto
  ON empleados (puesto_id)
  WHERE fecha_eliminacion IS NULL;

-- -------------------------
-- TABLA: roles_empleado (permisos por app)
-- Modelo grant/revoke
-- -------------------------
CREATE TABLE IF NOT EXISTS roles_empleado (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id BIGINT NOT NULL REFERENCES empleados(id) ON DELETE CASCADE,
  app_id BIGINT NOT NULL REFERENCES apps(id),
  rol VARCHAR(80) NOT NULL,

  otorgado_por_empleado_id BIGINT NULL,
  fecha_otorgamiento TIMESTAMPTZ NOT NULL DEFAULT NOW(),

  revocado_por_empleado_id BIGINT NULL,
  fecha_revocacion TIMESTAMPTZ NULL
);

-- Evita duplicar rol activo por app (activo = no revocado)
CREATE UNIQUE INDEX IF NOT EXISTS ux_roles_empleado_app_rol_activo
  ON roles_empleado (empleado_id, app_id, rol)
  WHERE fecha_revocacion IS NULL;

-- Consulta rápida de roles activos
CREATE INDEX IF NOT EXISTS ix_roles_empleado_activos
  ON roles_empleado (empleado_id, app_id)
  WHERE fecha_revocacion IS NULL;

-- -------------------------
-- TABLA: tokens_refresco
-- Técnica: mínimo necesario
-- -------------------------
CREATE TABLE IF NOT EXISTS tokens_refresco (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  empleado_id BIGINT NOT NULL REFERENCES empleados(id) ON DELETE CASCADE,

  hash_token TEXT NOT NULL,
  fecha_expiracion TIMESTAMPTZ NOT NULL,

  fecha_revocacion TIMESTAMPTZ NULL,
  revocado_por_empleado_id BIGINT NULL,

  reemplazado_por_id BIGINT NULL REFERENCES tokens_refresco(id) ON DELETE SET NULL,

  creado_por_empleado_id BIGINT NULL,
  fecha_creacion TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS ix_tokens_refresco_empleado
  ON tokens_refresco (empleado_id);

-- Solo una sesión activa por empleado (si esa es tu política)
CREATE UNIQUE INDEX IF NOT EXISTS ux_tokens_refresco_sesion_activa
  ON tokens_refresco (empleado_id)
  WHERE fecha_revocacion IS NULL;

-- Limpieza por expiración
CREATE INDEX IF NOT EXISTS ix_tokens_refresco_expiracion
  ON tokens_refresco (fecha_expiracion);

-- Evita duplicados de hash (recomendado)
CREATE UNIQUE INDEX IF NOT EXISTS ux_tokens_refresco_hash
  ON tokens_refresco (hash_token);

-- =====================================
-- SEED DATA
-- =====================================

-- -------------------------
-- Departamentos
-- -------------------------
INSERT INTO departamentos (nombre, descripcion)
VALUES
  ('Tecnología', 'Departamento de sistemas y desarrollo de software'),
  ('Recursos Humanos', 'Gestión de personal y talento'),
  ('Operaciones', 'Gestión operativa de la organización')
ON CONFLICT DO NOTHING;

-- -------------------------
-- Puestos
-- -------------------------
INSERT INTO puestos (nombre, descripcion)
VALUES
  ('Jefe de Departamento', 'Responsable de liderar y supervisar un departamento'),
  ('Desarrollador', 'Desarrollo y mantenimiento de aplicaciones'),
  ('Administrador de Sistemas', 'Gestión de infraestructura y servidores'),
  ('Analista', 'Análisis funcional y de procesos')
ON CONFLICT DO NOTHING;

-- -------------------------
-- Apps
-- -------------------------
INSERT INTO apps (clave, nombre)
VALUES
  ('reservas-salas', 'Sistema de Reservas de Salas')
ON CONFLICT DO NOTHING;

-- -------------------------
-- Empleado Administrador inicial
-- -------------------------
-- Nota: la contraseña debe estar previamente hasheada (ej. bcrypt/argon2)
INSERT INTO empleados (
  nombre,
  correo,
  contrasena_hash,
  puesto_id,
  departamento_id,
  estatus_id
)
VALUES (
  'Osiris Alejandro Meza Hernandez',
  'prueba@empresa.com',
  '$argon2d$v=19$m=12,t=3,p=1$a2tjZTU2YjZ1NjAwMDAwMA$9yanLfdVANSASgZrhJFsgA',
  (SELECT id FROM puestos WHERE LOWER(nombre) = LOWER('Jefe de Departamento') LIMIT 1),
  (SELECT id FROM departamentos WHERE LOWER(nombre) = LOWER('Tecnología') LIMIT 1),
  1
);

-- -------------------------
-- Rol ADMINISTRADOR para la app reservas-salas
-- -------------------------
INSERT INTO roles_empleado (
  empleado_id,
  app_id,
  rol,
  fecha_otorgamiento
)
VALUES (
  (SELECT id FROM empleados WHERE LOWER(correo) = LOWER('prueba@empresa.com') LIMIT 1),
  (SELECT id FROM apps WHERE LOWER(clave) = LOWER('reservas-salas') LIMIT 1),
  'ADMINISTRADOR',
  NOW()
)
ON CONFLICT DO NOTHING;


RESET ROLE;