-- OElite ClickHouse initialization
-- Runs once on first `docker compose up` via docker-entrypoint-initdb.d
-- Creates per-project databases (database-per-project pattern)

CREATE DATABASE IF NOT EXISTS origin_auth;
CREATE DATABASE IF NOT EXISTS apex;
CREATE DATABASE IF NOT EXISTS obelisk;
CREATE DATABASE IF NOT EXISTS synapse;
CREATE DATABASE IF NOT EXISTS stela;
CREATE DATABASE IF NOT EXISTS hermes;
CREATE DATABASE IF NOT EXISTS orion;
CREATE DATABASE IF NOT EXISTS kortex;
CREATE DATABASE IF NOT EXISTS oesterling;
CREATE DATABASE IF NOT EXISTS helios_core;
CREATE DATABASE IF NOT EXISTS sip;
CREATE DATABASE IF NOT EXISTS stela_runtime;
