# Environment Variables Reference

All platform settings are configured via the `.env` file at the root of the project.

> [!TIP]
> For a detailed guide on how to configure each section, generate secure secrets, and sync database roles, see the [Environment Configuration (.env) Guide](../guides/env_configuration.md).

---

## Complete `.env` Reference Table

| Variable | Default Value | Description |
| :--- | :--- | :--- |
| **`DOMAIN`** | `example.com` | Base domain name for public production deployments. |
| **`API_DOMAIN`** | `api.example.com` | Subdomain routed to the FastAPI Gateway by Traefik. |
| **`MQTT_DOMAIN`** | `mqtt.example.com` | Subdomain routed to the Mosquitto broker by Traefik. |
| **`ACME_EMAIL`** | `admin@example.com` | Contact email provided to Let's Encrypt for TLS expiry warnings. |
| **`POSTGRES_DB`** | `iot` | Database name created inside PostgreSQL / TimescaleDB. |
| **`POSTGRES_USER`** | `postgres` | Superuser account name for PostgreSQL. |
| **`POSTGRES_PASSWORD`** | *(Required)* | Superuser password for database initialization. |
| **`PG_MQTT_AUTH_PASSWORD`** | *(Required)* | Password for least-privilege role `iot_mqtt_auth`. |
| **`PG_BRIDGE_PASSWORD`** | *(Required)* | Password for least-privilege role `iot_bridge`. |
| **`PG_API_PASSWORD`** | *(Required)* | Password for least-privilege role `iot_api`. |
| **`BRIDGE_MQTT_USER`** | `svc_bridge` | Internal service username used by Python Ingestion Bridge. |
| **`BRIDGE_MQTT_PASSWORD`** | *(Required)* | Password matching Bcrypt hash in `db/init/03_roles.sql`. |
| **`API_MQTT_USER`** | `svc_api` | Internal service username used by FastAPI to forward HTTP writes. |
| **`API_MQTT_PASSWORD`** | *(Required)* | Password matching Bcrypt hash in `db/init/03_roles.sql`. |
| **`JWT_SECRET`** | *(Required)* | 32+ character cryptographic secret for signing user JWT tokens. |
| **`JWT_ALGORITHM`** | `HS256` | Algorithm used for JWT signatures. |
| **`ACCESS_TOKEN_EXPIRE_MINUTES`** | `15` | Expiry duration for user access tokens. |
| **`REFRESH_TOKEN_EXPIRE_DAYS`** | `30` | Expiry duration for persistent refresh tokens. |
| **`INITIAL_ADMIN_USERNAME`** | *(Optional)* | Username for the platform administrator (e.g. `admin`). Automatically created or promoted to `is_admin=true` on startup. |
| **`INITIAL_ADMIN_PASSWORD`** | *(Optional)* | Password for the initial administrator account. Automatically hashed using Argon2id and synchronized. |

---

## Production Security Recommendations

1. **Rotate Secrets:** Never use default passwords or default `JWT_SECRET` in production.
2. **Synchronize Role Hashes:** If you change `BRIDGE_MQTT_PASSWORD` or `API_MQTT_PASSWORD`, generate new Bcrypt hashes (cost 10) and update `db/init/03_roles.sql` prior to first database initialization.
3. **Restrict Docker Socket:** Ensure `/var/run/docker.sock` mounted into Traefik is protected and inaccessible from untrusted networks.
