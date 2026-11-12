# System Block Diagrams

This page contains detailed architectural block diagrams illustrating the data path, network segmentation, and service responsibilities of the ThingLarp platform.

---

## 1. High-Level Architecture Flow

```mermaid
flowchart TD
    subgraph Clients["External Clients"]
        ESP["ESP32 Hardware Nodes<br><code>Credentials: d_xxxx / secret</code>"]
        FLUTTER_M["Flutter Mobile & Desktop<br><code>MQTTS 8883 & HTTPS 443</code>"]
        FLUTTER_W["Flutter Web App<br><code>WSS 443 & HTTPS 443</code>"]
        SCRIPTS["Third-Party HTTP Clients<br><code>Headers: X-API-Key</code>"]
    end

    subgraph EdgeProxy["Edge Reverse Proxy (Docker Network: edge)"]
        TRAEFIK["Traefik v3<br><code>Automated Let's Encrypt TLS Termination</code>"]
    end

    subgraph AppServices["Application Services"]
        direction TB

        subgraph Broker["MQTT Broker (Eclipse Mosquitto)"]
            MOSQ["Mosquitto Daemon<br><code>:1883 (TCP) | :9001 (WS)</code>"]
            GOAUTH["mosquitto-go-auth Plugin<br><code>In-Memory Cache (go-cache)</code>"]
            MOSQ --- GOAUTH
        end

        subgraph BridgeService["Ingestion Bridge (Python)"]
            CONSUMER["aiomqtt Consumer<br><code>$share/ingest/channels/+/data</code>"]
            CACHE["FieldCache (RAM)<br><code>Guardrail: max_fields = 500</code>"]
            BATCHER["TelemetryBatcher (RAM)<br><code>Flush: 2000 items or 0.5s</code>"]
            CONSUMER --> CACHE --> BATCHER
        end

        subgraph ApiService["API Gateway (FastAPI)"]
            ROUTERS["REST API Routers<br><code>/auth • /channels • /devices • /mqtt • /data</code>"]
            PUB["Internal MQTT Publisher<br><code>svc_api superuser</code>"]
            ROUTERS --> PUB
        end
    end

    subgraph DBTier["Database Tier (Docker Network: backend - Isolated / No Internet)"]
        direction TB

        subgraph PostgresTimescale["PostgreSQL 16 + TimescaleDB (Database: iot)"]
            direction LR

            subgraph SchemaApp["app Schema (Relational Control Plane)"]
                USERS["users<br><code>Argon2id</code>"]
                CHANS["channels"]
                DEVS["devices<br><code>Bcrypt</code>"]
                SESS["mqtt_sessions<br><code>Bcrypt (24h)</code>"]
                KEYS["api_keys<br><code>SHA-256</code>"]
                FIELDS["channel_fields<br><code>Auto-discovered</code>"]
            end

            subgraph SchemaTelemetry["telemetry Schema (Hypertables & Rollups)"]
                POINTS[("telemetry.points<br><code>Compressed (3d) • Retained (90d)</code>")]
                MSGS[("telemetry.messages<br><code>Compressed (3d) • Retained (30d)</code>")]
                CAGG1[("telemetry.points_1m<br><code>1-min Rollup Continuous Aggregate</code>")]
                CAGG2[("telemetry.points_1h<br><code>1-hour Rollup Continuous Aggregate</code>")]
                POINTS -.-> CAGG1 -.-> CAGG2
            end

            subgraph SchemaMqtt["mqtt Schema (Security ACLs)"]
                V_USERS["v_users<br><code>UNION devices + sessions + svc</code>"]
                F_ACL["acl_topics(user, acc)<br><code>1=Read, 2=Write, 4=Sub</code>"]
            end
        end
    end

    ESP -->|"TCP TLS:8883"| TRAEFIK
    FLUTTER_M -->|"TCP TLS:8883"| TRAEFIK
    FLUTTER_M -->|"HTTPS:443"| TRAEFIK
    FLUTTER_W -->|"WSS:443"| TRAEFIK
    FLUTTER_W -->|"HTTPS:443"| TRAEFIK
    SCRIPTS -->|"HTTPS:443"| TRAEFIK

    TRAEFIK -->|"TCP :1883"| MOSQ
    TRAEFIK -->|"WS :9001"| MOSQ
    TRAEFIK -->|"HTTP :8000"| ROUTERS

    GOAUTH <-->|"Bcrypt Auth & ACL Queries"| SchemaMqtt

    MOSQ -->|"Shared Subscription"| CONSUMER
    BATCHER ==>|"COPY Protocol (Bulk Write)"| SchemaTelemetry
    PUB -->|"Forward HTTP Ingest"| MOSQ
    ROUTERS <-->|"App Metadata CRUD"| SchemaApp
    ROUTERS <-->|"Downsampled Queries"| SchemaTelemetry
```

---

## 2. Component Responsibility Diagram

```mermaid
flowchart TB
    subgraph INGRESS["1. INGRESS & SECURITY TIER"]
        direction LR
        P1["Port 8883 (MQTTS)<br>Devices & Mobile"]
        P2["Port 443 (HTTPS / WSS)<br>API & WebSockets"]
        P3["Port 80 (HTTP)<br>ACME Challenge"]
        TRAF["Traefik v3 Proxy<br>TLS Termination & Let's Encrypt"]
        P1 & P2 & P3 --> TRAF
    end

    subgraph MESSAGING["2. MQTT MESSAGING FABRIC"]
        direction LR
        MOSQ["Eclipse Mosquitto Core<br>In-Memory Pub/Sub Engine"]
        PLUGIN["mosquitto-go-auth Plugin<br>PostgreSQL Backend & In-Memory TTL Cache"]
        MOSQ <--> PLUGIN
    end

    subgraph PROCESSING["3. TELEMETRY PROCESSING PIPELINE"]
        direction LR
        subgraph BRIDGE["Python Ingestion Bridge"]
            direction TB
            BR_SUB["Async Subscriber<br>$share/ingest/channels/+/data"]
            BR_PARSER["orjson Fast Parser<br>Flatten Dynamic JSON"]
            BR_CACHE["Field Cache<br>In-Memory Mapping (name -> id)"]
            BR_BATCH["Batch Accumulator<br>2,000 pts or 500ms Flush"]
            BR_SUB --> BR_PARSER --> BR_CACHE --> BR_BATCH
        end
        subgraph API["FastAPI Application"]
            direction TB
            API_AUTH["Auth Router<br>JWT & Argon2id"]
            API_CHAN["Channel Router<br>Channels, Devices, Keys"]
            API_DATA["Data Query Router<br>Auto-downsampling Engine"]
            API_PUB["MQTT Client<br>Direct Ingest Publishing"]
        end
    end

    subgraph STORAGE["4. TIME-SERIES & RELATIONAL STORAGE"]
        direction TB
        subgraph PG["PostgreSQL 16 Engine"]
            S_APP["app schema<br>Users, Channels, Devices, Keys, Fields"]
            S_MQTT["mqtt schema<br>Auth Views & ACL Functions"]
        end
        subgraph TS["TimescaleDB Engine"]
            H_POINTS["telemetry.points Hypertable<br>Chunk Interval: 1 day<br>Segmentby: channel_id, field_id<br>Compression: after 3 days"]
            H_MSGS["telemetry.messages Hypertable<br>Raw JSON Payloads"]
            AGG_1M["telemetry.points_1m<br>Continuous Aggregate (1 min)"]
            AGG_1H["telemetry.points_1h<br>Continuous Aggregate (1 hour)"]
        end
    end

    TRAF -->|"TCP :1883"| MOSQ
    TRAF -->|"HTTP :8000"| API
    PLUGIN <-->|"SQL: v_users & acl_topics"| S_MQTT
    MOSQ -->|"MQTT Stream"| BR_SUB
    API_PUB -->|"Publish HTTP Ingest"| MOSQ
    BR_BATCH ==>|"COPY Protocol"| H_POINTS
    BR_BATCH ==>|"COPY Protocol"| H_MSGS
    API_CHAN <-->|"AsyncPG CRUD"| S_APP
    API_DATA <-->|"Downsampled SELECT"| H_POINTS
    API_DATA <-->|"Rollup SELECT"| AGG_1M
    API_DATA <-->|"Rollup SELECT"| AGG_1H
    H_POINTS -.-> AGG_1M -.-> AGG_1H
```

---

## 3. Simple Overview Diagram

```mermaid
flowchart LR
    subgraph CLIENTS["1. CLIENTS"]
        direction TB
        ESP["ESP32 / IoT Devices<br><i>(Sensors, Hardware)</i>"]
        APP["Flutter Application<br><i>(Mobile & Web)</i>"]
    end

    subgraph EDGE["2. EDGE PROXY"]
        TRAEFIK["Traefik v3<br><i>(Let's Encrypt TLS)</i>"]
    end

    subgraph BROKER["3. MQTT BROKER"]
        MOSQ["Mosquitto Broker<br><i>(mosquitto-go-auth)</i>"]
    end

    subgraph SERVICES["4. BACKEND SERVICES"]
        direction TB
        BRIDGE["Python Bridge<br><i>(Batch Ingestion)</i>"]
        API["FastAPI Gateway<br><i>(Auth & History Query)</i>"]
    end

    subgraph STORAGE["5. DATABASE TIER"]
        DB[("PostgreSQL + TimescaleDB<br><i>(Hypertables, Auth, Rollups)</i>")]
    end

    ESP -->|"Publish Telemetry"| TRAEFIK
    APP -->|"Live Stream (MQTT)"| TRAEFIK
    APP -->|"Manage & History (HTTPS)"| TRAEFIK

    TRAEFIK -->|"MQTTS :8883"| MOSQ
    TRAEFIK -->|"HTTPS :443"| API

    MOSQ -->|"Stream Ingest"| BRIDGE
    MOSQ <-->|"Auth & ACLs"| DB

    BRIDGE ==>|"Batch Write (COPY)"| DB
    API -->|"Forward HTTP Writes"| MOSQ
    API <-->|"Metadata & Analytics"| DB
```
