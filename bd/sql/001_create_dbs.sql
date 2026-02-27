-- 001_create_dbs.sql
-- Crea DBs y usuarios para microservicios

-- DBs
CREATE DATABASE authdb;
CREATE DATABASE bookingdb;

-- Users
CREATE USER authuser WITH PASSWORD 'authpass';
CREATE USER bookinguser WITH PASSWORD 'bookingpass';

-- Ownership
ALTER DATABASE authdb OWNER TO authuser;
ALTER DATABASE bookingdb OWNER TO bookinguser;

-- Hardening básico: que no puedan crear DB ni roles
ALTER ROLE authuser NOCREATEDB NOCREATEROLE;
ALTER ROLE bookinguser NOCREATEDB NOCREATEROLE;

-- (Opcional) Revocar acceso público a la DB
REVOKE ALL ON DATABASE authdb FROM PUBLIC;
REVOKE ALL ON DATABASE bookingdb FROM PUBLIC;

-- Permitir que cada user conecte a su DB
GRANT CONNECT ON DATABASE authdb TO authuser;
GRANT CONNECT ON DATABASE bookingdb TO bookinguser;