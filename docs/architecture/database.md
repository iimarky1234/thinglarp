# Database Architecture & TimescaleDB Optimization

The database is built on **PostgreSQL 16** with the **TimescaleDB** extension. It uses a strict three-schema separation to enforce least-privilege security boundaries and optimal disk-space efficiency.

---

## Schema Separation

```
Database: iot
├── app                  # Relational Control Plane (Metadata, Users, Channels)
├── telemetry            # Time-Series Engine (Hypertables, Continuous Aggregates)
└── mqtt                 # Broker Authentication (Views & ACL Functions for Mosquitto)
```

### 1. `app` Schema (Relational Control Plane)

Stores all application state and relational metadata:

- **`app.users`**: Registered users with Argon2id-hashed passwords.
- **`app.channels`**: Telemetry channels created by users. Supports public or private visibility.
- **`app.devices`**: Physical IoT hardware credentials (`d_<random>` username with Bcrypt-hashed password).
- **`app.mqtt_sessions`**: Short-lived (24-hour) frontend MQTT credentials (`s_<random>` username with Bcrypt password).
- **`app.api_keys`**: HTTP Ingestion/Export API keys (`X-API-Key`) stored as SHA-256 hashes with `'write'` or `'read'` scopes.
- **`app.channel_fields`**: Dynamically discovered field catalog per channel (maps field names like `"temperature"` to numeric `field_id`).

### 2. `telemetry` Schema (Time-Series Engine)

Stores high-frequency sensor readings as TimescaleDB **Hypertables**:

- **`telemetry.points`**: Narrow time-series table storing numeric metric points:
  ```sql
  CREATE TABLE telemetry.points (
      time        TIMESTAMPTZ NOT NULL,
      channel_id  INTEGER NOT NULL,
      field_id    INTEGER NOT NULL,
      value       DOUBLE PRECISION NOT NULL
  );
  SELECT create_hypertable('telemetry.points', 'time', chunk_time_interval => INTERVAL '1 day');
  ```
- **`telemetry.messages`**: Audit table storing complete raw JSON payloads and metadata:
  ```sql
  CREATE TABLE telemetry.messages (
      time        TIMESTAMPTZ NOT NULL,
      channel_id  INTEGER NOT NULL,
      device_id   INTEGER,
      payload     JSONB NOT NULL
  );
  SELECT create_hypertable('telemetry.messages', 'time', chunk_time_interval => INTERVAL '1 day');
  ```

### 3. `mqtt` Schema (Broker Auth & ACL Views)

Segregated views consumed directly by `mosquitto-go-auth`:

- **`mqtt.users_view`**: Returns `(username, password_hash)` by uniting active hardware devices, valid unexpired frontend sessions, and internal service accounts (`svc_bridge`, `svc_api`).
- **`mqtt.acl_topics(username, acc)`**: Stored function evaluated by the broker for every topic request:
  - `acc = 1` (Read): Can subscribe or read if channel is owned by user or is public.
  - `acc = 2` (Write): Can publish if username is the authorized device assigned to that channel or an internal service account.
  - `acc = 4` (Subscribe): Same logic as Read.

---

## TimescaleDB Compression Policies

To minimize NVMe/SSD storage costs, TimescaleDB natively compresses chunks older than 3 days using columnar compression:

```sql
ALTER TABLE telemetry.points SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'channel_id, field_id',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('telemetry.points', INTERVAL '3 days');
```

- **Compression Ratio:** Typical telemetry data achieves **90% to 95% compression** (10x–20x disk reduction).
- **Segmenting:** By grouping identical `channel_id` and `field_id` sequences together, compression achieves maximum delta-of-delta bit-packing.

---

## Continuous Aggregates (Downsampling)

To ensure instantaneous chart loading across millions of data points, TimescaleDB maintains background materialized rollups:

### 1-Minute Rollups (`telemetry.points_1m`)
```sql
CREATE MATERIALIZED VIEW telemetry.points_1m
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 minute', time) AS bucket,
    channel_id,
    field_id,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*) AS count
FROM telemetry.points
GROUP BY bucket, channel_id, field_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('telemetry.points_1m',
    start_offset => INTERVAL '1 day',
    end_offset => INTERVAL '1 minute',
    schedule_interval => INTERVAL '1 minute');
```

### 1-Hour Rollups (`telemetry.points_1h`)
```sql
CREATE MATERIALIZED VIEW telemetry.points_1h
WITH (timescaledb.continuous) AS
SELECT 
    time_bucket('1 hour', bucket) AS bucket,
    channel_id,
    field_id,
    AVG(avg_value) AS avg_value,
    MIN(min_value) AS min_value,
    MAX(max_value) AS max_value,
    SUM(count) AS count
FROM telemetry.points_1m
GROUP BY time_bucket('1 hour', bucket), channel_id, field_id
WITH NO DATA;

SELECT add_continuous_aggregate_policy('telemetry.points_1h',
    start_offset => INTERVAL '7 days',
    end_offset => INTERVAL '1 hour',
    schedule_interval => INTERVAL '1 hour');
```

---

## Least-Privilege Database Roles

| PostgreSQL Role | Access Scope |
| :--- | :--- |
| **`iot_mqtt_auth`** | Read-only access to `mqtt.users_view` and execute access to `mqtt.acl_topics()`. Has zero access to `app.*` or `telemetry.*`. |
| **`iot_bridge`** | Read access to `app.channel_fields`, write access to `app.channel_fields` (for auto-discovery), and append (`INSERT`/`COPY`) access to `telemetry.points` and `telemetry.messages`. |
| **`iot_api`** | Full CRUD on `app.*`, `SELECT` on `telemetry.*` (including rollups), and `INSERT` on `telemetry.*` for HTTP write fallback. |
