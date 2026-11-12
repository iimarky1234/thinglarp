#!/bin/bash
# 03_roles.sh: Dynamically creates least-privilege database roles and computes Bcrypt service hashes from .env
set -e

psql -v ON_ERROR_STOP=1 --username "${POSTGRES_USER:-postgres}" --dbname "${POSTGRES_DB:-iot}" <<EOSQL
-- Enable pgcrypto for automated Bcrypt password hashing
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- 1. Create or update least-privilege roles using environment passwords
DO
\$do\$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_mqtt_auth') THEN
      CREATE ROLE iot_mqtt_auth WITH LOGIN PASSWORD '${PG_MQTT_AUTH_PASSWORD}';
   ELSE
      ALTER ROLE iot_mqtt_auth WITH PASSWORD '${PG_MQTT_AUTH_PASSWORD}';
   END IF;

   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_bridge') THEN
      CREATE ROLE iot_bridge WITH LOGIN PASSWORD '${PG_BRIDGE_PASSWORD}';
   ELSE
      ALTER ROLE iot_bridge WITH PASSWORD '${PG_BRIDGE_PASSWORD}';
   END IF;

   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_api') THEN
      CREATE ROLE iot_api WITH LOGIN PASSWORD '${PG_API_PASSWORD}';
   ELSE
      ALTER ROLE iot_api WITH PASSWORD '${PG_API_PASSWORD}';
   END IF;
END
\$do\$;

-- ============================================================================
-- PRIVILEGES: iot_mqtt_auth
-- ============================================================================
GRANT USAGE ON SCHEMA mqtt TO iot_mqtt_auth;
GRANT USAGE ON SCHEMA app TO iot_mqtt_auth;

GRANT SELECT ON mqtt.credentials TO iot_mqtt_auth;
GRANT SELECT ON mqtt.superusers TO iot_mqtt_auth;
GRANT EXECUTE ON FUNCTION mqtt.acl_topics(TEXT, INT) TO iot_mqtt_auth;

GRANT SELECT ON app.devices TO iot_mqtt_auth;
GRANT SELECT ON app.channels TO iot_mqtt_auth;
GRANT SELECT ON app.users TO iot_mqtt_auth;
GRANT SELECT ON app.mqtt_sessions TO iot_mqtt_auth;
GRANT SELECT ON app.service_accounts TO iot_mqtt_auth;

-- ============================================================================
-- PRIVILEGES: iot_bridge
-- ============================================================================
GRANT USAGE ON SCHEMA telemetry TO iot_bridge;
GRANT USAGE ON SCHEMA app TO iot_bridge;

GRANT INSERT ON telemetry.points TO iot_bridge;
GRANT INSERT ON telemetry.messages TO iot_bridge;

GRANT SELECT, INSERT, UPDATE ON app.channel_fields TO iot_bridge;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO iot_bridge;
GRANT SELECT ON app.channels TO iot_bridge;

-- ============================================================================
-- PRIVILEGES: iot_api
-- ============================================================================
GRANT USAGE ON SCHEMA app, telemetry, mqtt TO iot_api;

GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO iot_api;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO iot_api;

GRANT SELECT, INSERT, DELETE ON telemetry.points TO iot_api;
GRANT SELECT, INSERT, DELETE ON telemetry.messages TO iot_api;
GRANT SELECT ON telemetry.points_1m TO iot_api;
GRANT SELECT ON telemetry.points_1h TO iot_api;

-- ============================================================================
-- SEED SERVICE ACCOUNTS
-- ============================================================================
-- Automatically compute Bcrypt hashes for bridge and API MQTT service accounts
INSERT INTO app.service_accounts (username, password_hash)
VALUES 
    ('svc_bridge', crypt('${BRIDGE_MQTT_PASSWORD}', gen_salt('bf', 10))),
    ('svc_api',    crypt('${API_MQTT_PASSWORD}', gen_salt('bf', 10)))
ON CONFLICT (username) DO UPDATE 
SET password_hash = EXCLUDED.password_hash;
EOSQL
