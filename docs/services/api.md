# REST & Authentication API Gateway

The **API Gateway** (`api/`) is a high-performance **FastAPI** service responsible for user authentication, channel management, device provisioning, API key issuance, and telemetry queries.

---

## Technical Highlights

- **Framework:** FastAPI with Python 3.12+ and `uvicorn`.
- **Database Driver:** `asyncpg` with a pooled connection manager (`api/database.py`).
- **Security:**
  - **User Passwords:** Argon2id (via `pwdlib[argon2]`).
  - **Hardware / Session Credentials:** Bcrypt (cost 10) for compatibility with `mosquitto-go-auth`.
  - **Tokens:** Signed JWTs (HS256) with 15-minute access expiration and 30-day refresh tokens.
  - **HTTP API Keys:** Cryptographic SHA-256 hash storage.
- **Direct MQTT Forwarding:** An internal persistent MQTT client (`api/mqtt_client.py`) forwards HTTP data writes directly into the broker so live WebSocket and MQTT subscribers receive immediate events.

---

## Router Modules

| Router | Path Prefix | Description |
| :--- | :--- | :--- |
| **`auth`** | `/auth` | User registration, login (JWT generation), token refresh, and user profile. |
| **`channels`** | `/channels` | Channel CRUD, field listings, and public/private channel access control. |
| **`devices`** | `/channels/{id}/devices` | Hardware device provisioning, credentials rotation, and listing. |
| **`keys`** | `/channels/{id}/keys` | Write / Read API key generation and revocation. |
| **`mqtt`** | `/mqtt` | Short-lived (24h) MQTT session generation for frontend clients (`POST /mqtt/session`). |
| **`data`** | `/channels/{id}/data` | Telemetry query with auto-downsampling and HTTP ingestion (`POST`). |

---

## Dynamic Telemetry Query & Auto-Downsampling

When querying telemetry (`GET /channels/{id}/data`), the API dynamically selects the optimal storage representation based on the requested time window:

```python
# api/routers/data.py
if resolution == "auto":
    delta = end_time - start_time
    if delta > timedelta(days=14):
        target_resolution = "1h" # Query telemetry.points_1h
    elif delta > timedelta(hours=6):
        target_resolution = "1m" # Query telemetry.points_1m
    else:
        target_resolution = "raw" # Query telemetry.points
```

### Response Schema

```json
{
  "channel_id": 42,
  "start": "2026-11-12T00:00:00Z",
  "end": "2026-11-12T12:00:00Z",
  "resolution": "1m",
  "fields": {
    "1": "temperature",
    "2": "humidity"
  },
  "points": [
    {
      "time": "2026-11-12T00:00:00Z",
      "field": "temperature",
      "field_id": 1,
      "value": 23.4,
      "min": 22.8,
      "max": 24.1,
      "count": 60
    }
  ]
}
```

---

## HTTP Ingestion Endpoint (`Dual-Ingress`)

Devices or external webhook services can publish via simple HTTP:

```http
POST /channels/42/data
Host: api.example.com
X-API-Key: tl_write_xxxxxxxxxxxxxxxxxxxx
Content-Type: application/json

{
  "temperature": 25.4,
  "humidity": 60.2,
  "status": "normal"
}
```

1. The API validates the `X-API-Key` against `app.api_keys` where `scope = 'write'`.
2. It publishes the payload directly to the internal MQTT broker on topic `channels/42/data`.
3. Mosquitto fans the message out to the Python Ingestion Bridge (for DB persistence) and all active Flutter/Web subscribers simultaneously.
