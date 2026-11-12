-- 03_roles.sql: Least-privilege database roles and initial service seeds

DO
$do$
BEGIN
   -- 1. mosquitto-go-auth role
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_mqtt_auth') THEN
      CREATE ROLE iot_mqtt_auth WITH LOGIN PASSWORD 'iot_mqtt_auth_secret';
   END IF;

   -- 2. Python Bridge role
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_bridge') THEN
      CREATE ROLE iot_bridge WITH LOGIN PASSWORD 'iot_bridge_secret';
   END IF;

   -- 3. FastAPI Service role
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'iot_api') THEN
      CREATE ROLE iot_api WITH LOGIN PASSWORD 'iot_api_secret';
   END IF;
END
$do$;

-- ============================================================================
-- PRIVILEGES: iot_mqtt_auth
-- ============================================================================
GRANT USAGE ON SCHEMA mqtt TO iot_mqtt_auth;
GRANT USAGE ON SCHEMA app TO iot_mqtt_auth;

GRANT SELECT ON mqtt.credentials TO iot_mqtt_auth;
GRANT SELECT ON mqtt.superusers TO iot_mqtt_auth;
GRANT EXECUTE ON FUNCTION mqtt.acl_topics(TEXT, INT) TO iot_mqtt_auth;

-- Base tables queried by the views
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

-- Ingest telemetry
GRANT INSERT ON telemetry.points TO iot_bridge;
GRANT INSERT ON telemetry.messages TO iot_bridge;

-- Dynamic field discovery and channel limits
GRANT SELECT, INSERT, UPDATE ON app.channel_fields TO iot_bridge;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA app TO iot_bridge;
GRANT SELECT ON app.channels TO iot_bridge;


-- ============================================================================
-- PRIVILEGES: iot_api
-- ============================================================================
GRANT USAGE ON SCHEMA app, telemetry, mqtt TO iot_api;

-- Full CRUD on application metadata
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA app TO iot_api;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA app TO iot_api;

-- Read telemetry and downsampled aggregates
GRANT SELECT, DELETE ON telemetry.points TO iot_api;
GRANT SELECT, DELETE ON telemetry.messages TO iot_api;
GRANT SELECT ON telemetry.points_1m TO iot_api;
GRANT SELECT ON telemetry.points_1h TO iot_api;


-- ============================================================================
-- SEED SERVICE ACCOUNTS
-- ============================================================================
-- Internal credentials for Bridge and API publisher (Superusers in Mosquitto)
-- Passwords:
--   svc_bridge: bridge_mqtt_secret
--   svc_api:    api_mqtt_secret
INSERT INTO app.service_accounts (username, password_hash)
VALUES 
    ('svc_bridge', '$2b$10$OfNp4BPzD5Vzhz1WUqeIZOaed17/0lk56Zliy9zI2/dOJc3aSXIqC'),
    ('svc_api',    '$2b$10$yyJvE8jSAzzCDg8GKPhMBOQxgTgIJ2J/jzQoXJtX890/5FnYaGGmG')
ON CONFLICT (username) DO NOTHING;
