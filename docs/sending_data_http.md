# HTTP REST Ingestion

Sending telemetry to ThingLarp via HTTP is simple and requires only a single `POST` request.

---

## Ingestion Endpoint

```http
POST https://api.iimarky123.io.vn/channels/{channel_id}/data
```

### Authentication Header
Provide your Channel API Key in the `X-API-Key` header:
```http
X-API-Key: tl_ak_xxxxxxxxxxxxxxxxxxxxxxxx
Content-Type: application/json
```

---

## Payload Format

Send arbitrary JSON key-value pairs. Numeric values (integers, floats) are charted automatically.

```json
{
  "temperature": 24.85,
  "humidity": 61.2,
  "co2_ppm": 412,
  "battery_v": 3.78
}
```

### Response
On success, the API returns `202 Accepted`:
```json
{
  "status": "accepted",
  "channel_id": 42
}
```

---

## Code Examples

### 1. cURL (CLI)
```bash
curl -X POST "https://api.iimarky123.io.vn/channels/42/data" \
  -H "X-API-Key: tl_ak_YOUR_API_KEY_HERE" \
  -H "Content-Type: application/json" \
  -d '{"temperature": 24.8, "humidity": 60.5}'
```

### 2. Python (requests)
```python
import requests

API_URL = "https://api.iimarky123.io.vn/channels/42/data"
API_KEY = "tl_ak_YOUR_API_KEY_HERE"

payload = {
    "temperature": 24.8,
    "humidity": 60.5,
    "soil_moisture": 380
}

response = requests.post(
    API_URL,
    headers={"X-API-Key": API_KEY},
    json=payload
)

print(f"Status: {response.status_code}")
```

### 3. JavaScript / Node.js (fetch)
```javascript
const res = await fetch("https://api.iimarky123.io.vn/channels/42/data", {
  method: "POST",
  headers: {
    "X-API-Key": "tl_ak_YOUR_API_KEY_HERE",
    "Content-Type": "application/json"
  },
  body: JSON.stringify({
    temperature: 24.8,
    humidity: 60.5
  })
});

console.log(`Status: ${res.status}`);
```

---

## Querying Historical Telemetry

You can read back recent points directly via HTTP:

### Latest Values Snapshot
```bash
curl -X GET "https://api.iimarky123.io.vn/channels/42/latest" \
  -H "X-API-Key: tl_ak_YOUR_API_KEY_HERE"
```

### Feeds History Query
```bash
curl -X GET "https://api.iimarky123.io.vn/channels/42/history?limit=50&order=desc" \
  -H "X-API-Key: tl_ak_YOUR_API_KEY_HERE"
```
*(If your channel is marked as **Public**, the `X-API-Key` header can be omitted on read queries!)*
