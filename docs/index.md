# ThingLarp IoT Platform

**ThingLarp** is a high-performance, completely unconstrained IoT telemetry and analytics platform built as an open, modern alternative to ThingSpeak. 

It provides native MQTT ingestion, dynamic field auto-discovery without prior schema definitions, microsecond time-series storage powered by TimescaleDB, and an cross-platform Flutter dashboard for desktop, mobile, and web.

!!! note "⚡ Vibe Coding Disclaimer"
    This project was mostly **vibe coded** by **Antigravity** (Google DeepMind's agentic AI assistant) in close collaboration with **@iimarky123**. While designed with production-grade architectural patterns, microservices, and end-to-end verification tests, please review all configurations and security secrets before deploying to critical production infrastructure.

---

## Key Capabilities

=== "🚀 No Rate Limits"
    Unlike legacy IoT platforms that throttle free tiers to 1 update every 15–60 seconds, ThingLarp enforces **zero artificial rate limits**. High-frequency sensors (vibration, acoustics, motor RPM) can stream at 50Hz–100Hz continuously.

=== "📈 Unlimited Dynamic Fields"
    No more restriction to 8 numeric fields (`field1`...`field8`). Devices can publish arbitrary JSON key-value pairs (e.g. `{"temp": 24.5, "co2_ppm": 420, "gyro_z": -0.012}`). Fields are dynamically discovered, indexed, and charted on the fly.

=== "🔒 Strict Multi-Tenant Security"
    Every MQTT publish and subscribe is strictly authorized at the broker level using `mosquitto-go-auth` and PostgreSQL views. Devices can only publish to their provisioned channel; client apps can only subscribe to channels they own or are public.

=== "⚡ TimescaleDB Continuous Aggregates"
    Raw sensor readings are ingested into compressed hypertables with background continuous aggregate views (`points_1m` and `points_1h`). Queries across months of data return in milliseconds.

=== "📱 Cross-Platform Flutter Dashboard"
    A native Flutter client for Linux Desktop, macOS, Windows, Android, iOS, and Web featuring real-time MQTT streaming, dynamic metric cards, and responsive time-series charts powered by `fl_chart`.

---

## System Architecture at a Glance

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

## Technology Stack

| Layer | Component | Description |
| :--- | :--- | :--- |
| **Edge Proxy** | [Traefik v3](services/traefik.md) | Reverse proxy terminating TLS, automated Let's Encrypt certificates, TCP/HTTP routing. |
| **MQTT Broker** | [Eclipse Mosquitto](services/mosquitto.md) | High-concurrency MQTT broker with `mosquitto-go-auth` plugin validating credentials via Postgres. |
| **Ingestion Engine** | [Python Bridge](services/bridge.md) | High-throughput asynchronous daemon using `aiomqtt`, `orjson`, and PostgreSQL `COPY` batching. |
| **Database** | [TimescaleDB](architecture/database.md) | PostgreSQL 16 engine with automated chunk compression and 1-minute / 1-hour continuous rollups. |
| **REST API** | [FastAPI](services/api.md) | Asynchronous REST gateway for user authentication (JWT/Argon2id), channel management, and telemetry queries. |
| **Client App** | [Flutter 3.x](client/flutter.md) | Cross-platform frontend with reactive state management (`provider`) and interactive charting (`fl_chart`). |

---

## Quick Navigation

- [Getting Started Guide](guides/getting_started.md) — Deploy the entire platform via Docker Compose in under 5 minutes.
- [Architecture Deep Dive](architecture/overview.md) — Comprehensive technical design of the backend microservices.
- [Hardware Provisioning](guides/hardware_provisioning.md) — Example code for ESP32 (Arduino / MicroPython) and Raspberry Pi.
- [REST API Reference](reference/api_reference.md) — Complete endpoint schemas, authentication, and responses.
- [Flutter Client Integration](client/flutter.md) — Building and running the cross-platform application.
