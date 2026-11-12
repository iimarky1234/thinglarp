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
  {"id": 1, "name": "temperature", "data_type": "numeric", "created_at": "..."},
  {"id": 2, "name": "humidity", "data_type": "numeric", "created_at": "..."}
]
```

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
  "name": "ESP32_Outdoor_Unit"
}
```
**Response (201 Created):**
```json
{
  "id": 1,
  "channel_id": 1,
  "name": "ESP32_Outdoor_Unit",
  "mqtt_username": "d_0a1b2c3d4e",
  "mqtt_password": "raw_generated_password_revealed_once",
  "created_at": "2026-11-12T00:00:00Z"
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
