# Getting Started Guide

This step-by-step guide walks you through setting up and running the entire ThingLarp IoT platform locally or on a cloud virtual machine.

---

## Prerequisites

Ensure you have the following installed on your host machine:

- **Docker Engine** (v24.0 or newer) and **Docker Compose v2**
- **Git**
- **Python 3.11+** (for test scripts and CLI tools)
- **Flutter SDK 3.24+** (if building or running the Flutter dashboard)

---

## 1. Clone the Repository & Configure Environment

```bash
git clone https://github.com/your-username/thinglarp-fr.git
cd thinglarp-fr
```

Copy the example environment configuration:

```bash
cp .env.example .env
```

Review the `.env` settings:
- In local development, the default database passwords and service secrets can be used as-is.
- For production, replace `DOMAIN`, `ACME_EMAIL`, `POSTGRES_PASSWORD`, and `JWT_SECRET` with strong, unique secrets.

> [!TIP]
> For a complete parameter breakdown, secret generation commands, and production security checklists, see the dedicated [Environment Configuration (.env) Guide](env_configuration.md).

---

## 2. Start the Backend Infrastructure

Start all Docker containers using Docker Compose:

```bash
docker compose up -d --build
```

Verify that all services are healthy and running:

```bash
docker compose ps
```

You should see 5 running containers:

| Container Name | Service | Status | Exposed Ports |
| :--- | :--- | :--- | :--- |
| `iot_traefik` | Traefik v3 | Up | **`80`, `443`, `8883` (Sole Public Ingress)**, `127.0.0.1:8080` |
| `iot_mosquitto` | Mosquitto | Up | `1883`, `9001` (internal Docker networks only) |
| `iot_api` | FastAPI Gateway | Up | `8000` (internal Docker networks only) |
| `iot_bridge` | Python Bridge | Up | internal |
| `iot_timescaledb` | TimescaleDB | Up (healthy) | `5432` (isolated internal network) |

---

## 3. Verify System Health

Run an HTTP health check through Traefik:

```bash
# Direct via Traefik (using domain host header)
curl -H "Host: ${API_DOMAIN:-api.example.com}" http://localhost/health
```

Expected response:
```json
{"status":"healthy","database":"connected","time":"2026-11-12T05:40:00Z"}
```

---

## 4. Run the End-to-End Simulation

Execute the automated end-to-end verification script to confirm database creation, MQTT broker authentication, Python ingestion, TimescaleDB rollups, and API key ingestion:

```bash
python scripts/e2e_simulation.py
```

All 14 simulation steps will execute and print green checkmarks (`✅`).

---

## 5. Launch the Flutter Application

Navigate to the `app/` folder and launch the native desktop application:

```bash
cd app/
flutter run -d linux
```

Log in with the pre-provisioned administrator credentials:
- **Username:** `admin`
- **Password:** `admin123456`

Or register a new account directly from the login screen!
