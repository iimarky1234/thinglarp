-- 02_mqtt_views.sql: mosquitto-go-auth views and ACL function

-- ============================================================================
-- MQTT AUTHENTICATION INTERFACE
-- ============================================================================

-- Unified credentials view queried by mosquitto-go-auth
CREATE OR REPLACE VIEW mqtt.credentials AS
-- 1. Hardware Devices
SELECT d.mqtt_username AS username, d.mqtt_password_hash AS password_hash
FROM app.devices d
JOIN app.channels c ON c.id = d.channel_id
JOIN app.users    u ON u.id = c.owner_id
WHERE d.is_active AND u.is_active
UNION ALL
-- 2. Flutter App Sessions (Short-lived, active)
SELECT s.username, s.password_hash
FROM app.mqtt_sessions s
WHERE s.expires_at > now() AND s.revoked_at IS NULL
UNION ALL
-- 3. Internal Service Accounts (Bridge, API internal publisher)
SELECT username, password_hash
FROM app.service_accounts;


-- Superuser view: accounts that bypass standard ACLs
CREATE OR REPLACE VIEW mqtt.superusers AS
SELECT username FROM app.service_accounts;


-- ============================================================================
-- MQTT AUTHORIZATION (ACL) FUNCTION
-- ============================================================================
-- mosquitto-go-auth executes: SELECT mqtt.acl_topics($1, $2)
-- $1: username
-- $2: acc (1 = read/receive, 2 = write/publish, 4 = subscribe)
CREATE OR REPLACE FUNCTION mqtt.acl_topics(p_username TEXT, p_acc INT)
RETURNS SETOF TEXT
LANGUAGE sql STABLE SECURITY DEFINER
SET search_path = app, mqtt, pg_temp
AS $$
    -- 1. Devices: May ONLY publish (p_acc = 2) to their specific channel topics
    SELECT 'channels/' || d.channel_id || '/' || t.suffix
    FROM app.devices d
    CROSS JOIN (VALUES ('data'), ('status')) AS t(suffix)
    WHERE d.mqtt_username = p_username 
      AND d.is_active 
      AND p_acc = 2

    UNION ALL

    -- 2. App Sessions: May read (p_acc = 1) or subscribe (p_acc = 4) to owned or public channels
    SELECT 'channels/' || c.id || '/+'
    FROM app.mqtt_sessions s
    JOIN app.channels c ON (c.owner_id = s.user_id OR c.is_public)
    WHERE s.username = p_username
      AND s.expires_at > now() 
      AND s.revoked_at IS NULL
      AND p_acc IN (1, 4)

    UNION ALL

    -- 3. Superusers / Service accounts: Full access
    SELECT '#'
    FROM app.service_accounts sa
    WHERE sa.username = p_username;
$$;
