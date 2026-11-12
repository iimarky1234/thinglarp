# MQTT Broker Service (Mosquitto)

ThingLarp uses **Eclipse Mosquitto** augmented with the **`mosquitto-go-auth`** plugin to provide high-concurrency, strictly authenticated MQTT messaging.

---

## Network Listeners & Protocols

The broker exposes three network listeners:

| Port | Protocol | Listener Role | Target Clients |
| :--- | :--- | :--- | :--- |
| **`1883`** | Plain TCP | Internal Docker network & Local testing | Bridge service, internal API forwarder, local devices |
| **`8883`** | TCP + TLS (via Traefik) | Secure public MQTTS | Production IoT devices, Flutter desktop & mobile apps |
| **`9001`** | WebSockets / WSS (via Traefik) | Browser WebSockets | Flutter Web applications |

---

## Dynamic Authentication (`mosquitto-go-auth`)

Rather than maintaining static password files (`passwd`) or static ACL text files, `mosquitto-go-auth` queries PostgreSQL in real time.

### Configuration (`mosquitto.conf`)

```ini
auth_plugin /usr/lib/mosquitto/go-auth.so
auth_opt_backends postgres

# PostgreSQL Connection
auth_opt_pg_host timescaledb
auth_opt_pg_port 5432
auth_opt_pg_dbname iot
auth_opt_pg_user iot_mqtt_auth
auth_opt_pg_password iot_mqtt_auth_secret

# Password validation uses Bcrypt
auth_opt_hasher bcrypt

# Authentication SQL Query
auth_opt_pg_userquery SELECT password_hash FROM mqtt.users_view WHERE username = $1 LIMIT 1

# Superuser Query (for internal microservices: svc_bridge, svc_api)
auth_opt_pg_superquery SELECT CASE WHEN username IN ('svc_bridge', 'svc_api') THEN true ELSE false END FROM mqtt.users_view WHERE username = $1

# ACL Authorization Query
# $1: Username
# $2: Access flag (1 = Read, 2 = Write, 4 = Subscribe)
auth_opt_pg_aclquery SELECT topic FROM mqtt.acl_topics($1, $2::int)
```

### In-Memory High-Performance Caching

To prevent pounding the database with identical authorization queries during bursts, `mosquitto-go-auth` enables an in-memory cache:

```ini
auth_opt_cache true
auth_opt_cache_type go-cache
auth_opt_auth_cache_seconds 30
auth_opt_acl_cache_seconds 30
auth_opt_auth_jitter_seconds 5
auth_opt_acl_jitter_seconds 5
```

---

## Topic Hierarchy & Permissions

All messages conform to standard topic conventions:

| Topic Pattern | Permission Flag | Who Can Access |
| :--- | :--- | :--- |
| `channels/{id}/data` | **Write** (`2`) | Device assigned to channel `{id}` or `svc_api` |
| `channels/{id}/data` | **Read / Sub** (`1` / `4`) | User owning channel `{id}`, valid session, or if channel is public |
| `channels/{id}/status` | **Write** (`2`) | Device assigned to channel `{id}` (LWT message) |
| `$share/ingest/channels/+/data` | **Sub** (`4`) | `svc_bridge` (Ingestion Bridge shared subscription) |
| `#` (All Topics) | **Superuser** | `svc_bridge` (Read-only), `svc_api` (Write-only) |
