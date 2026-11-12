# Configuring the Environment (`.env`)

The `.env` file at the root of the project is the single source of truth for the entire ThingLarp platform. It supplies configuration parameters, database credentials, domain names, and cryptographic keys to Docker Compose, which automatically distributes them across all microservices.

---

## 1. Initial Setup

To begin, copy the provided template to create your active `.env` file:

```bash
cp .env.example .env
```

Ensure the file permissions restrict read access to authorized system users:

```bash
chmod 600 .env
```

---

## 2. Section-by-Section Configuration

### Section 1: Domain & TLS Configuration

These variables configure **Traefik v3** for routing and automated SSL/TLS certificate issuance via Let's Encrypt:

```ini
# Domain & TLS Configuration
DOMAIN=example.com
API_DOMAIN=api.example.com
MQTT_DOMAIN=mqtt.example.com
ACME_EMAIL=admin@example.com
```

- **`DOMAIN`**: The base apex domain of your organization or project.
- **`API_DOMAIN`**: Subdomain routed to the FastAPI Gateway (HTTPS on port `443`).
- **`MQTT_DOMAIN`**: Subdomain routed to the Mosquitto broker with TLS termination (MQTTS on port `8883`).
- **`ACME_EMAIL`**: The email address submitted to Let's Encrypt for registration and expiration warnings.

> [!IMPORTANT]
> **DNS Prerequisite for Production:** Before starting Traefik, ensure you have configured `A` or `CNAME` records with your DNS registrar pointing `api.example.com` and `mqtt.example.com` to your public server IP. Let's Encrypt requires successful HTTP-01 challenge resolution on port `80`.
> 
> **For Local Development / LAN:** You can leave these as defaults or point them to `localhost`. Local traffic accesses the API on `http://localhost:8000` and MQTT on port `1883` directly without TLS.

---

### Section 2: PostgreSQL Superuser & Database

These settings configure the core PostgreSQL 16 container running TimescaleDB:

```ini
# PostgreSQL Root & App Database
POSTGRES_DB=iot
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_supersecret_change_me
```

- **`POSTGRES_DB`**: The database name initialized inside the cluster (defaults to `iot`).
- **`POSTGRES_USER`**: The PostgreSQL administrative superuser account (defaults to `postgres`).
- **`POSTGRES_PASSWORD`**: The master password for the administrative user. Replace with a random password.

---

### Section 3: Service Database Passwords

ThingLarp enforces strict least-privilege security. Each service connects to PostgreSQL using a dedicated database role with restricted table permissions:

```ini
# Service Database Passwords (automatically synced to db/init/03_roles.sh)
PG_MQTT_AUTH_PASSWORD=iot_mqtt_auth_secret
PG_BRIDGE_PASSWORD=iot_bridge_secret
PG_API_PASSWORD=iot_api_secret
```

- **`PG_MQTT_AUTH_PASSWORD`**: Password for the `iot_mqtt_auth` user, consumed by the `mosquitto-go-auth` plugin to query credentials and ACLs.
- **`PG_BRIDGE_PASSWORD`**: Password for the `iot_bridge` user, used by the Python Ingestion Bridge to bulk `COPY` telemetry into TimescaleDB.
- **`PG_API_PASSWORD`**: Password for the `iot_api` user, used by the FastAPI Gateway for user registration, channel management, and telemetry queries.

> [!NOTE]
> **Fully Automated Synchronization:** Database roles and passwords are automatically generated on first cluster startup via [`db/init/03_roles.sh`](file:///home/iimarky123/Projects/thinglarp-fr/db/init/03_roles.sh). You no longer need to edit static SQL scripts.

---

### Section 4: Internal Service MQTT Credentials

The Python Bridge and FastAPI Gateway connect to the Mosquitto broker as dedicated internal service clients:

```ini
# Internal Service MQTT Credentials
BRIDGE_MQTT_USER=svc_bridge
BRIDGE_MQTT_PASSWORD=bridge_mqtt_secret
API_MQTT_USER=svc_api
API_MQTT_PASSWORD=api_mqtt_secret
```

- **`BRIDGE_MQTT_USER` / `BRIDGE_MQTT_PASSWORD`**: Credentials used by the Python Bridge to subscribe to `$share/ingest/channels/+/data`.
- **`API_MQTT_USER` / `API_MQTT_PASSWORD`**: Credentials used by FastAPI to forward HTTP data writes (`POST /channels/{id}/data`) directly into the broker.

#### How Mosquitto Validates Service Credentials
The Mosquitto `mosquitto-go-auth` plugin validates MQTT passwords against Bcrypt hashes in PostgreSQL.

During cluster initialization, [`db/init/03_roles.sh`](file:///home/iimarky123/Projects/thinglarp-fr/db/init/03_roles.sh) uses PostgreSQL's native `pgcrypto` extension (`crypt(..., gen_salt('bf', 10))`) to auto-compute Bcrypt hashes directly from `BRIDGE_MQTT_PASSWORD` and `API_MQTT_PASSWORD`. You do not need to generate hashes manually!

Similarly, Mosquitto's Go-Auth plugin dynamically receives `POSTGRES_DB` and `PG_MQTT_AUTH_PASSWORD` from `.env` on container startup via [`mosquitto/docker-entrypoint.sh`](file:///home/iimarky123/Projects/thinglarp-fr/mosquitto/docker-entrypoint.sh) and [`mosquitto/mosquitto.conf.template`](file:///home/iimarky123/Projects/thinglarp-fr/mosquitto/mosquitto.conf.template).

---

### Section 5: Security & JWT Token Settings

These settings configure JSON Web Token issuance for user authentication in the API Gateway and Flutter app:

```ini
# Security
JWT_SECRET=super_secret_random_jwt_key_32_chars_min
JWT_ALGORITHM=HS256
ACCESS_TOKEN_EXPIRE_MINUTES=15
REFRESH_TOKEN_EXPIRE_DAYS=30
```

- **`JWT_SECRET`**: Cryptographic secret key used to sign and verify user JWTs. Must be at least 32 characters long.
- **`JWT_ALGORITHM`**: Cryptographic signing algorithm (defaults to `HS256`).
- **`ACCESS_TOKEN_EXPIRE_MINUTES`**: Lifespan of short-lived access tokens (default: 15 minutes).
- **`REFRESH_TOKEN_EXPIRE_DAYS`**: Lifespan of persistent refresh tokens (default: 30 days).

---

### Section 6: Initial Administrator Account

Configure an initial administrator account to bootstrap platform management without manual SQL commands:

```ini
# Initial Platform Administrator
INITIAL_ADMIN_USERNAME=admin
INITIAL_ADMIN_PASSWORD=AdminPassword123!
```

- **`INITIAL_ADMIN_USERNAME`**: The username for the administrator account. If the user does not exist, the API automatically provisions it with `is_admin = true`. If the user already exists, the API ensures `is_admin = true`.
- **`INITIAL_ADMIN_PASSWORD`**: The administrator password, automatically hashed with Argon2id. If updated in `.env`, the API synchronizes the password upon container restart.

---

## 3. Generating Secure Production Secrets

For production environments, you can generate cryptographically secure random values using `openssl` or `python`:

=== "Generate JWT Secret (64 hex characters)"
    ```bash
    openssl rand -hex 32
    ```

=== "Generate Strong Passwords"
    ```bash
    openssl rand -base64 24
    ```

---

## 4. Applying Changes to Running Containers

When you modify `.env`, restart the Docker Compose stack to apply the new environment variables:

```bash
# Restart services to pick up new environment variables
docker compose up -d

# If database passwords or service credentials were changed from scratch:
docker compose down -v
docker compose up -d --build
```

> [!CAUTION]
> Running `docker compose down -v` deletes PostgreSQL storage volumes. Only use `-v` during initial setup or when you intend to wipe the database.
