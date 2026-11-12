# Simulation & Verification Scripts

ThingLarp includes automated Python simulation scripts in the `scripts/` directory to facilitate integration testing, stress testing, and dashboard demonstration without physical hardware.

---

## 1. End-to-End Test Suite (`scripts/e2e_simulation.py`)

The end-to-end simulation script executes a full lifecycle verification across all platform microservices:

```bash
python scripts/e2e_simulation.py
```

### Steps Executed
1. **User Registration & Login:** Generates a new unique user and retrieves a JWT access token.
2. **Channel Creation:** Provisions a new private channel via REST.
3. **Hardware Device Provisioning:** Creates an ESP32 hardware credential with Bcrypt password.
4. **MQTT Frontend Session:** Requests a short-lived ephemeral session token for a client app.
5. **Real-Time MQTT Pub/Sub:** Connects the app subscriber and ESP32 publisher over MQTT, verifying real-time packet delivery.
6. **Multi-Tenant Security Enforcement:** Verifies that attempting to publish to unauthorized channels is immediately rejected by Mosquitto's ACL engine.
7. **Dynamic Field Auto-Discovery:** Publishes 10 unconfigured dynamic fields (`voltage`, `current`, `power`, `rpm`, `vibration_x`, etc.) and asserts they are registered in `app.channel_fields`.
8. **TimescaleDB Continuous Aggregates:** Confirms 1-minute and 1-hour continuous aggregate rollups contain valid materialized buckets.
9. **HTTP Ingestion:** Generates a Write API Key and sends data via `POST /channels/{id}/data`, confirming both broker fan-out and database persistence.

---

## 2. Live Telemetry Stream Generator (`scripts/stream_generator.py`)

The stream generator creates fluctuating waveforms (sine/cosine oscillations with simulated sensor noise) to animate graphs in the Flutter dashboard in real time.

### Usage via MQTT Device Credentials
```bash
./scripts/stream_generator.py \
  --channel 1 \
  --device d_xxxxxxxx your_device_password \
  --interval 1.5
```

### Usage via HTTP Write API Key
```bash
./scripts/stream_generator.py \
  --channel 1 \
  --key tl_write_xxxxxxxxxxxxxxxx \
  --interval 1.0
```

### Command Line Options

| Option | Default | Description |
| :--- | :--- | :--- |
| `--channel` | *(Required)* | Target channel ID. |
| `--interval` | `1.5` | Interval in seconds between consecutive telemetry messages. |
| `--count` | `None` (Infinite) | Total number of messages to publish before stopping. |
| `--device` | *(Mutually Exclusive)* | Device username and password for native MQTT transmission. |
| `--key` | *(Mutually Exclusive)* | Channel Write API key (`X-API-Key`) for HTTP ingestion. |
