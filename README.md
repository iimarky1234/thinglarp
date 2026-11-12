# ThingLarp IoT Platform

[![Documentation](https://img.shields.io/badge/docs-thinglarp.iimarky123.io.vn-blue?style=for-the-badge&logo=materialformkdocs)](https://thinglarp.iimarky123.io.vn)
[![GitHub](https://img.shields.io/badge/GitHub-iimarky1234%2Fthinglarp-181717?style=for-the-badge&logo=github)](https://github.com/iimarky1234/thinglarp)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-v2-2496ED?style=for-the-badge&logo=docker)](docker-compose.yml)
[![FastAPI](https://img.shields.io/badge/FastAPI-009688?style=for-the-badge&logo=fastapi&logoColor=white)](api/)
[![TimescaleDB](https://img.shields.io/badge/TimescaleDB-FDB515?style=for-the-badge&logo=postgresql&logoColor=black)](db/)
[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?style=for-the-badge&logo=flutter&logoColor=white)](app/)

**ThingLarp** is a high-performance, completely unconstrained IoT telemetry and analytics platform built as an open-source, modern alternative to ThingSpeak.

> 📖 **Full Documentation & Guides:** [https://thinglarp.iimarky123.io.vn](https://thinglarp.iimarky123.io.vn)
>
> ⚡ **Disclaimer:** This project was mostly **vibe coded** by **Antigravity** (Google DeepMind's agentic AI assistant) in collaboration with **@iimarky123**. While built with production-grade architectural patterns, microservices, and end-to-end test verification, make sure to review configurations and security secrets before deploying to critical production environments!

---

## 🌟 Key Highlights

- **Zero Artificial Rate Limits:** High-frequency sensors (vibration, acoustics, motor RPM) can stream telemetry continuously at 50Hz–100Hz without being throttled to legacy 15-second windows.
- **Unlimited Dynamic Fields:** No restriction to fixed `field1`...`field8` slots. Devices publish arbitrary JSON payloads (`{"temp": 24.2, "co2_ppm": 420, "gyro_z": -0.012}`). Fields are dynamically discovered, indexed, and charted on the fly.
- **Strict Multi-Tenant ACLs:** Broker-level security powered by `mosquitto-go-auth` and PostgreSQL views. Devices can only publish to their assigned channel; dashboards can only subscribe to owned or public channels.
- **TimescaleDB Continuous Aggregates:** Ingests raw points into compressed hypertables with background 1-minute (`telemetry.points_1m`) and 1-hour (`telemetry.points_1h`) rollups for millisecond chart rendering across millions of rows.
- **Dual-Ingress Parity:** HTTP REST writes (`POST /channels/{id}/data`) publish directly to the internal MQTT broker so live subscribers see updates instantly.
- **Cross-Platform Flutter Dashboard:** Native client for Linux Desktop, macOS, Windows, Android, iOS, and Web featuring real-time MQTT streaming, dynamic metric badges, and interactive time-series charts.

---

## 🏗 Architecture Overview

```mermaid
flowchart TD
    %% ==========================================
    %% TIER 1: CLIENTS
    %% ==========================================
    subgraph CLIENTS ["1. EDGE CLIENTS & HARDWARE"]
        direction LR
        ESP["<b>ESP32 / IoT Hardware Nodes</b><br/><i>Sensors, MicroPython, Arduino C++</i><br/><code>Topic: channels/{id}/data</code>"]
        APP["<b>Flutter Cross-Platform Application</b><br/><i>Desktop • Mobile • Web</i><br/><code>Live MQTT Stream & REST Dashboard</code>"]
    end

    %% ==========================================
    %% TIER 2: EDGE PROXY & INGRESS
    %% ==========================================
    subgraph EDGE ["2. EDGE INGRESS & TLS TERMINATION"]
        TRAEFIK["<b>Traefik v3 Reverse Proxy</b><br/><i>Automated Let's Encrypt TLS Certificates</i><br/><code>Ports: :8883 (MQTTS) • :443 (HTTPS/WSS) • :80 (ACME)</code>"]
    end

    %% ==========================================
    %% TIER 3: MESSAGING & ROUTING
    %% ==========================================
    subgraph MESSAGING ["3. MQTT MESSAGING FABRIC"]
        MOSQ["<b>Eclipse Mosquitto Broker</b><br/><i>High-concurrency pub/sub with mosquitto-go-auth</i><br/><code>Dynamic PostgreSQL ACLs & In-Memory TTL Caching</code>"]
    end

    %% ==========================================
    %% TIER 4: BACKEND PROCESSING & STORAGE
    %% ==========================================
    subgraph PROCESSING ["4. INGESTION & RELATIONAL STORAGE"]
        direction LR
        BRIDGE["<b>Python Ingestion Bridge</b><br/><i>aiomqtt + orjson</i><br/><code>$share/ingest/channels/+/data</code><br/><i>Micro-batch COPY Buffer</i>"]
        API["<b>FastAPI REST Gateway</b><br/><i>JWT & Argon2id Auth</i><br/><i>Auto-downsampling Engine</i><br/><i>Direct MQTT Forwarder</i>"]
        DB[("<b>PostgreSQL 16 + TimescaleDB</b><br/><i>Relational Metadata (app)</i><br/><i>Hypertables (telemetry.points)</i><br/><i>Continuous Aggregates (1m / 1h)</i>")]
    end

    %% Client traffic
    ESP ==>|"MQTTS :8883 (Publish Telemetry)"| TRAEFIK
    APP ==>|"MQTTS :8883 / WSS :443 (Live Stream)"| TRAEFIK
    APP ==>|"HTTPS :443 (REST API & Auth)"| TRAEFIK

    %% Ingress to Broker & API
    TRAEFIK ==>|"TCP :1883"| MOSQ
    TRAEFIK ==>|"HTTP :8000"| API

    %% Internal messaging
    MOSQ <===>|"Bcrypt Auth & Topic ACL Queries"| DB
    MOSQ ==>|"Shared Load-Balanced Ingestion"| BRIDGE
    API -.->|"Forward HTTP Writes"| MOSQ

    %% Storage writes & queries
    BRIDGE ===>|"Binary COPY Flush (2,000 pts / 500ms)"| DB
    API <===>|"Metadata CRUD & Analytical Rollups"| DB

    %% Custom High-Visibility Styling
    classDef clientStyle fill:#1e293b,stroke:#38bdf8,stroke-width:3px,color:#ffffff;
    classDef edgeStyle fill:#0f172a,stroke:#06b6d4,stroke-width:3px,color:#ffffff;
    classDef brokerStyle fill:#1e1e24,stroke:#f59e0b,stroke-width:3px,color:#ffffff;
    classDef serviceStyle fill:#1e1b4b,stroke:#a855f7,stroke-width:3px,color:#ffffff;
    classDef dbStyle fill:#064e3b,stroke:#10b981,stroke-width:3px,color:#ffffff;

    class ESP,APP clientStyle;
    class TRAEFIK edgeStyle;
    class MOSQ brokerStyle;
    class BRIDGE,API serviceStyle;
    class DB dbStyle;
```

---

## 🗂 Repository Structure

```text
.
├── docker-compose.yml        # Multi-container orchestration (5 microservices)
├── .env.example              # Centralized environment configuration template
├── api/                      # FastAPI Gateway (Auth, Channels, Devices, Keys, Data)
├── bridge/                   # High-throughput asynchronous Python Ingestion Bridge
├── mosquitto/                # Mosquitto config with mosquitto-go-auth plugin & caching
├── traefik/                  # Traefik v3 reverse proxy & automated Let's Encrypt TLS
├── db/                       # PostgreSQL & TimescaleDB initialization scripts (01-03)
├── app/                      # Cross-platform Flutter client (Mobile/Desktop/Web)
├── docs/                     # Comprehensive MkDocs documentation source
├── mkdocs.yml                # MkDocs Material theme & site configuration
└── scripts/                  # Automated E2E verification & live waveform generators
```

---

## 🚀 Quickstart

### 1. Clone & Configure Environment
```bash
git clone https://github.com/iimarky1234/thinglarp.git
cd thinglarp
cp .env.example .env
chmod 600 .env
# Edit .env with your domain names and database credentials
```
> For a full explanation of every configuration setting, see the [Environment Configuration Guide](https://thinglarp.iimarky123.io.vn/guides/env_configuration/).

### 2. Start the Backend Infrastructure
```bash
docker compose up -d --build
```

Verify that all 5 containers are running:
```bash
docker compose ps
```

### 3. Launch the Flutter Application
```bash
cd app/
flutter run -d linux
```
*Default Administrator Credentials:*
- **Username:** `admin`
- **Password:** `admin123456`
*(You can also register any new account directly from the app screen).*

### 4. Run Live Waveform Streamer (Optional)
To animate real-time charts in the Flutter app without physical hardware:
```bash
./scripts/stream_generator.py --channel 1 --key <YOUR_WRITE_API_KEY> --interval 1.5
```

---

## 📚 Complete Documentation

All architectural designs, hardware provisioning examples, API references, and security models are published at:

👉 **[https://thinglarp.iimarky123.io.vn](https://thinglarp.iimarky123.io.vn)**

- **[System Architecture](https://thinglarp.iimarky123.io.vn/architecture/overview/)**
- **[Interactive Block Diagrams](https://thinglarp.iimarky123.io.vn/architecture/block_diagrams/)**
- **[Database & TimescaleDB Hypertables](https://thinglarp.iimarky123.io.vn/architecture/database/)**
- **[Hardware Provisioning (ESP32, MicroPython, Python)](https://thinglarp.iimarky123.io.vn/guides/hardware_provisioning/)**
- **[REST API Reference](https://thinglarp.iimarky123.io.vn/reference/api_reference/)**
- **[MQTT Topics & Permissions](https://thinglarp.iimarky123.io.vn/reference/mqtt_topics/)**
- **[Environment Variables Reference](https://thinglarp.iimarky123.io.vn/reference/environment_variables/)**

---

## 📄 License
This project is licensed under the MIT License.
