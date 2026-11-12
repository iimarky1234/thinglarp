# REST API Specification

The REST API is exposed by the FastAPI Gateway service at `http://localhost:8000` (or `https://api.yourdomain.com`).

---

## Authentication

All protected endpoints require an HTTP `Authorization` header containing a valid Bearer token:

```http
Authorization: Bearer <ACCESS_TOKEN>
```

---

## Auth Endpoints

### Register User
```http
POST /auth/register
```
**Request Body:**
```json
{
  "username": "alice",
  "password": "Password123!"
}
```
**Response (201 Created):**
```json
{
  "id": 1,
  "username": "alice",
  "created_at": "2026-11-12T00:00:00Z"
}
```

---

### Login (Obtain Tokens)
```http
POST /auth/login
```
**Request Body:**
```json
{
  "username": "alice",
  "password": "Password123!"
}
```
**Response (200 OK):**
```json
{
  "access_token": "eyJhbGciOi...",
  "refresh_token": "Au1R5Xk...",
  "token_type": "bearer",
  "expires_in_minutes": 15
}
```

---

### Refresh Access Token
```http
POST /auth/refresh
```
**Request Body:**
```json
{
  "refresh_token": "Au1R5Xk..."
}
```
**Response (200 OK):** Returns fresh `access_token`.

---

## Channels Endpoints

### List User Channels
```http
GET /channels
```
**Response (200 OK):** Array of Channel objects.

---

### Create Channel
```http
POST /channels
```
**Request Body:**
```json
{
  "name": "Greenhouse Alpha",
  "description": "Climate and moisture monitoring",
  "is_public": false
}
```

---

### Get Channel Details
```http
GET /channels/{channel_id}
```

---

### List Channel Fields
```http
GET /channels/{channel_id}/fields
```
**Response (200 OK):**
```json
[
  {
    "id": 1,
    "channel_id": 1,
    "key": "temperature",
    "label": "Ambient Temp",
    "unit": "°C",
    "value_type": "number",
    "widget_type": "line",
    "first_seen_at": "2026-11-12T04:38:34Z"
  }
]
```

---

### Update Channel Field Metadata & Widget Type
```http
PATCH /channels/{channel_id}/fields/{field_id}
Authorization: Bearer <jwt_access_token>
```
**Request Body:**
```json
{
  "label": "Living Room Temp",
  "unit": "°C",
  "widget_type": "gauge"
}
```
*`widget_type` accepts `line`, `gauge`, `kpi`, or `status`.*

---

## Hardware Devices Endpoints

### List Devices
```http
GET /channels/{channel_id}/devices
```

---

### Provision Device
```http
POST /channels/{channel_id}/devices
```
**Request Body:**
```json
{
  "name": "ESP32_Outdoor_Unit",
  "scope": "pubsub"
}
```
*`scope` accepts `publish` (default), `subscribe`, or `pubsub`.*

**Response (201 Created):**
```json
{
  "id": 1,
  "channel_id": 1,
  "name": "ESP32_Outdoor_Unit",
  "scope": "pubsub",
  "is_active": true,
  "mqtt_username": "dev_ch1_1",
  "mqtt_password": "<generated_password>",
  "created_at": "2026-11-12T04:38:34Z"
}
```

---

### Update Device Access Control & Status
```http
PATCH /channels/{channel_id}/devices/{device_id}
Authorization: Bearer <jwt_access_token>
```
**Request Body:**
```json
{
  "name": "ESP32_Outdoor_Unit_Renamed",
  "scope": "pubsub",
  "is_active": true
}
```
*`scope` accepts `publish`, `subscribe`, or `pubsub`. Setting `is_active: false` immediately denies MQTT authentication.*

**Response (200 OK):**
```json
{
  "id": 1,
  "channel_id": 1,
  "name": "ESP32_Outdoor_Unit_Renamed",
  "mqtt_username": "dev_ch1_1",
  "mqtt_password": "<password>",
  "scope": "pubsub",
  "is_active": true,
  "created_at": "2026-11-12T04:38:34Z"
}
```

---

### Reset Device Password
```http
POST /channels/{channel_id}/devices/{device_id}/reset-password
Authorization: Bearer <jwt_access_token>
```
Regenerates and updates the MQTT password for the specified device, returning the updated credentials. Previous credentials are immediately invalidated.

**Response (200 OK):**
```json
{
  "id": 1,
  "channel_id": 1,
  "name": "ESP32_Outdoor_Unit",
  "mqtt_username": "dev_ch1_1",
  "mqtt_password": "<newly_generated_password>",
  "scope": "pubsub",
  "is_active": true,
  "created_at": "2026-11-12T04:38:34Z"
}
```

---

## API Keys Endpoints

### List API Keys
```http
GET /channels/{channel_id}/keys
```

---

### Generate API Key
```http
POST /channels/{channel_id}/keys
```
**Request Body:**
```json
{
  "scope": "write" // "write" or "read"
}
```
**Response (201 Created):**
```json
{
  "id": 1,
  "channel_id": 1,
  "scope": "write",
  "api_key": "tl_write_xxxxxxxxxxxxxxxxxxxx", // Revealed once
  "created_at": "2026-11-12T00:00:00Z"
}
```

---

## MQTT Sessions Endpoint

### Request Frontend MQTT Session
```http
POST /mqtt/session
```
**Response (200 OK):**
```json
{
  "username": "s_f7e8d9c0b1",
  "password": "temporary_session_password",
  "expires_at": "2026-11-13T00:00:00Z"
}
```

---

## Telemetry Data Endpoints

### Query Telemetry Series
```http
GET /channels/{channel_id}/data?resolution=auto&fields=temperature,humidity&start=2026-11-11T00:00:00Z
```
**Query Parameters:**
- `resolution`: `auto`, `raw`, `1m`, or `1h`.
- `fields`: Comma-separated list of field names (optional).
- `start`: ISO-8601 start timestamp.
- `end`: ISO-8601 end timestamp.

---

### HTTP Telemetry Ingestion
```http
POST /channels/{channel_id}/data
X-API-Key: tl_write_xxxxxxxxxxxxxxxxxxxx
Content-Type: application/json
```
**Request Body:** Arbitrary JSON key-value pairs:
```json
{
  "temperature": 23.8,
  "humidity": 61.2,
  "battery_v": 3.78
}
```

---

### Export Telemetry Data (CSV / JSON)
```http
GET /channels/{channel_id}/export?format=csv&resolution=raw
X-API-Key: tl_read_xxxxxxxxxxxxxxxxxxxx
```
**Query Parameters:**
- `format`: `csv` or `json`.
- `resolution`: `auto`, `raw`, `1m`, or `1h`.
- `fields`: Comma-separated list of field keys (optional).
- `start`: ISO 8601 timestamp.
- `end`: ISO 8601 timestamp.

**Response (200 OK):**
Streaming CSV file attachment or JSON payload.

---

### Clear Channel Telemetry Data
```http
DELETE /channels/{channel_id}/data
Authorization: Bearer <jwt_access_token>
```
**Response (200 OK):**
```json
{
  "status": "cleared",
  "channel_id": 1,
  "detail": "All telemetry points and messages have been cleared."
}
```

---

### Dispatch Downlink Device Commands
```http
POST /channels/{channel_id}/commands
Authorization: Bearer <jwt_access_token>
```
*Can also authenticate via `X-API-Key: tl_write_...`.*

**Request Body:**
```json
{
  "payload": {
    "relay": 1,
    "state": "ON"
  },
  "subtopic": "commands"
}
```
Publishes the payload directly to MQTT topic `channels/{channel_id}/{subtopic}` with QoS 1. Subscribed hardware nodes and clients receive the command immediately.

**Response (200 OK):**
```json
{
  "status": "dispatched",
  "channel_id": 1,
  "topic": "channels/1/commands",
  "payload": {
    "relay": 1,
    "state": "ON"
  }
}
```

---

### Import Historical Telemetry (CSV)
```http
POST /channels/{channel_id}/import
Authorization: Bearer <jwt_access_token>
Content-Type: text/csv
```
*Can also authenticate via `X-API-Key: tl_write_...`.*
Accepts generic CSV (`time,temperature,humidity,...`) or ThingSpeak CSV export format (`created_at,entry_id,field1,field2,...`). Auto-registers new channel fields.

**Request Body (Raw text or JSON `{"csv": "..."}`):**
```csv
created_at,entry_id,field1,field2
2026-11-12T00:00:00Z,1,24.5,60.2
2026-11-12T01:00:00Z,2,25.1,58.9
```

**Response (200 OK):**
```json
{
  "status": "imported",
  "channel_id": 1,
  "points_imported": 2,
  "fields_discovered": ["field1", "field2"]
}
```

---

## Administration Endpoints

*Note: All `/admin/*` endpoints require the authenticated user to have `is_admin = true`.*

### List All Users
```http
GET /admin/users
```
**Response (200 OK):**
```json
[
  {
    "id": 1,
    "username": "tester",
    "is_active": true,
    "is_admin": false,
    "created_at": "2026-11-12T04:38:34Z",
    "channel_count": 2,
    "device_count": 3
  }
]
```

---

### Create User
```http
POST /admin/users
```
**Request Body:**
```json
{
  "username": "charlie",
  "password": "Password123!",
  "is_admin": false
}
```

---

### Update User (Toggle Active / Role / Reset Password)
```http
PATCH /admin/users/{user_id}
```
**Request Body:**
```json
{
  "is_active": false,
  "is_admin": true,
  "password": "NewSecurePassword123!"
}
```

---

### Delete User
```http
DELETE /admin/users/{user_id}
```
**Response (204 No Content)**

---

### System Statistics
```http
GET /admin/stats
```
**Response (200 OK):**
```json
{
  "total_users": 15,
  "active_users": 14,
  "total_channels": 42,
  "total_devices": 98,
  "total_points": 1450200
}
```
