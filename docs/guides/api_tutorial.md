# Developer API Tutorial & Integration Guide

Welcome to the **ThingLarp Developer Tutorial**! This guide is designed to be beginner-friendly while providing production-ready code examples for streaming and querying telemetry using the ThingLarp REST API and MQTT broker.

---

## 🌟 Why the ThingLarp API is Different

If you have used legacy IoT platforms like ThingSpeak, you may be familiar with strict limits:
- ❌ Throttled to 1 update every 15–60 seconds.
- ❌ Restricted to 8 numeric fields (`field1` through `field8`).
- ❌ Rigid predefined database schemas.

**ThingLarp removes these restrictions entirely:**
- ⚡ **Zero Artificial Rate Limits:** Stream at 10Hz, 50Hz, or 100Hz continuously.
- 📈 **Unlimited Dynamic Fields:** Send arbitrary JSON payloads (e.g., `{"temperature": 24.5, "pressure_kpa": 101.3, "status": "nominal"}`).
- 🔄 **Dual-Ingress Parity:** Any data sent via HTTP REST is forwarded immediately to live MQTT subscribers, and vice-versa.

---

## 🔑 Core Concepts & Authentication

Before making requests, understand the three essential identifiers:

| Identifier | Where to Find It | What It's Used For |
| :--- | :--- | :--- |
| **Channel ID** | Top of Channel screen (e.g. `42`) | Identifies your telemetry stream container. |
| **API Key (`X-API-Key`)** | Channel Detail -> **API Keys** Tab | Used for authenticating HTTP REST requests (`write` or `read` scope). |
| **Device Credentials** | Channel Detail -> **Devices** Tab | Dedicated username (`d_...`) and password for hardware connecting via MQTT. |

---

## 🛠️ In-App Tutorial & Code Generator

Did you know the **ThingLarp Flutter App** includes a built-in interactive code generator?

* **From the Channels screen:** Click the graduation cap icon (**`🎓`**) in the top AppBar.
* **From a specific Channel:** Click the **API Guide** icon (**`🎓`**) or tap the **HTTP REST API Tutorials** banner inside the **API Keys** tab.
* **Pre-Filled Code:** All code snippets automatically populate with your active **Channel ID**, **API Base URL**, and **API Key**!
* **Live Test Console:** Includes an in-app ping simulator to send test JSON packets directly to your channel without leaving the UI.

---

## 🚀 Tutorial 1: Sending Telemetry (HTTP POST)

To ingest telemetry, send an HTTP `POST` request to `/channels/{channel_id}/data`.

### Request Specifications
* **URL:** `https://api.iimarky123.io.vn/channels/{channel_id}/data`
* **Method:** `POST`
* **Headers:**
  * `Content-Type: application/json`
  * `X-API-Key: tl_write_xxxxxxxxxxxxxxxx`
* **Body:** Any valid JSON object with key-value pairs.

### Interactive Code Examples

=== "cURL (Bash / Terminal)"
    ```bash
    curl -X POST "https://api.iimarky123.io.vn/channels/1/data" \
      -H "Content-Type: application/json" \
      -H "X-API-Key: tl_write_YOUR_KEY_HERE" \
      -d '{
        "temperature": 24.5,
        "humidity": 58.2,
        "battery_v": 3.75,
        "status": "online"
      }'
    ```

=== "Python (requests)"
    ```python
    import requests

    URL = "https://api.iimarky123.io.vn/channels/1/data"
    API_KEY = "tl_write_YOUR_KEY_HERE"

    payload = {
        "temperature": 24.5,
        "humidity": 58.2,
        "battery_v": 3.75,
        "status": "online"
    }

    headers = {
        "Content-Type": "application/json",
        "X-API-Key": API_KEY,
    }

    response = requests.post(URL, headers=headers, json=payload)
    print(f"Status: {response.status_code}, Response: {response.json()}")
    ```

=== "JavaScript (Node.js / Browser fetch)"
    ```javascript
    const url = "https://api.iimarky123.io.vn/channels/1/data";
    const apiKey = "tl_write_YOUR_KEY_HERE";

    const payload = {
      temperature: 24.5,
      humidity: 58.2,
      battery_v: 3.75,
      status: "online"
    };

    async function sendTelemetry() {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "X-API-Key": apiKey
        },
        body: JSON.stringify(payload)
      });

      const result = await response.json();
      console.log("Telemetry sent:", result);
    }

    sendTelemetry();
    ```

=== "ESP32 (Arduino C++)"
    ```cpp
    #include <WiFi.h>
    #include <HTTPClient.h>

    const char* ssid = "YOUR_WIFI_SSID";
    const char* password = "YOUR_WIFI_PASSWORD";

    const char* serverUrl = "https://api.iimarky123.io.vn/channels/1/data";
    const char* apiKey = "tl_write_YOUR_KEY_HERE";

    void setup() {
      Serial.begin(115200);
      WiFi.begin(ssid, password);
      while (WiFi.status() != WL_CONNECTED) {
        delay(500);
        Serial.print(".");
      }
      Serial.println("\nWiFi connected!");
    }

    void loop() {
      if (WiFi.status() == WL_CONNECTED) {
        HTTPClient http;
        http.begin(serverUrl);
        http.addHeader("Content-Type", "application/json");
        http.addHeader("X-API-Key", apiKey);

        // Read sensor values or simulate:
        float temp = 24.5 + (random(-10, 10) / 10.0);
        float hum = 60.0 + (random(-20, 20) / 10.0);

        String payload = "{\"temperature\":" + String(temp, 2) +
                         ",\"humidity\":" + String(hum, 2) +
                         ",\"status\":\"active\"}";

        int httpCode = http.POST(payload);
        Serial.printf("HTTP POST Result: %d\n", httpCode);
        http.end();
      }
      delay(5000); // Send reading every 5 seconds
    }
    ```

=== "MicroPython"
    ```python
    import urequests
    import ujson
    import time

    URL = "https://api.iimarky123.io.vn/channels/1/data"
    API_KEY = "tl_write_YOUR_KEY_HERE"

    headers = {
        "Content-Type": "application/json",
        "X-API-Key": API_KEY
    }

    data = {
        "temperature": 23.8,
        "humidity": 65.2,
        "firmware": "v1.2.0"
    }

    response = urequests.post(URL, headers=headers, data=ujson.dumps(data))
    print("Status:", response.status_code, "Body:", response.text)
    response.close()
    ```

### Expected Response
On success, the API returns HTTP `202 Accepted`:
```json
{
  "status": "published",
  "channel_id": 1
}
```

---

## 📊 Tutorial 2: Querying Telemetry (HTTP GET)

### 1. Fetch Channel History / Feeds (Configurable Limit)
Retrieve the exact number of recent telemetry packets you want using the `limit` query parameter (default: 20, max: 1000):

```bash
# Fetch the last 10 data packets (newest first)
curl -X GET "https://api.iimarky123.io.vn/channels/1/history?limit=10&order=desc" \
  -H "X-API-Key: tl_read_YOUR_KEY_HERE"
```

To fetch only the single latest reading, simply pass `limit=1` (or use `/latest`):
```bash
curl -X GET "https://api.iimarky123.io.vn/channels/1/history?limit=1" \
  -H "X-API-Key: tl_read_YOUR_KEY_HERE"
```

Response:
```json
{
  "channel_id": 1,
  "count": 2,
  "limit": 10,
  "order": "desc",
  "feeds": [
    {
      "time": "2026-11-12T17:10:05.123456Z",
      "payload": {
        "temperature": 25.4,
        "humidity": 61.2,
        "status": "online"
      }
    },
    {
      "time": "2026-11-12T17:09:05.100234Z",
      "payload": {
        "temperature": 25.1,
        "humidity": 61.5,
        "status": "online"
      }
    }
  ]
}
```


---

### 2. Query Historical Time-Series
Query downsampled historical charts:

```bash
curl -X GET "https://api.iimarky123.io.vn/channels/1/data?resolution=auto&fields=temperature,humidity" \
  -H "X-API-Key: tl_read_YOUR_KEY_HERE"
```

#### Query Parameters:
* **`resolution`**:
  * `auto` *(Default)*: Automatically chooses the best resolution based on your time window.
  * `raw`: Returns individual microsecond sensor readings (best for windows < 6 hours).
  * `1m`: Returns 1-minute pre-computed rollup aggregates (best for windows up to 14 days).
  * `1h`: Returns 1-hour pre-computed rollup aggregates (best for multi-month queries).
* **`fields`**: Optional comma-separated list of field keys to filter (e.g. `temperature,battery_v`).
* **`start`** / **`end`**: Optional ISO 8601 timestamps (defaults to the last 24 hours).

---

### 3. Downloading / Exporting Telemetry (CSV & JSON)

ThingLarp provides a streaming export endpoint to download telemetry for offline analysis in Excel, pandas, or backup systems:

=== "Export as CSV Spreadsheet"
    ```bash
    curl -X GET "https://api.iimarky123.io.vn/channels/1/export?format=csv&resolution=raw" \
      -H "X-API-Key: tl_read_YOUR_KEY_HERE" \
      -o channel_1_telemetry.csv
    ```

=== "Export as JSON Array"
    ```bash
    curl -X GET "https://api.iimarky123.io.vn/channels/1/export?format=json&resolution=1m" \
      -H "X-API-Key: tl_read_YOUR_KEY_HERE" \
      -o channel_1_telemetry.json
    ```

---

### 4. Clearing Channel Telemetry Data

To wipe all historical readings and message logs while retaining field definitions:

```bash
curl -X DELETE "https://api.iimarky123.io.vn/channels/1/data" \
  -H "X-API-Key: tl_write_YOUR_KEY_HERE"
```

Response:
```json
{
  "status": "cleared",
  "channel_id": 1,
  "detail": "All telemetry points and messages have been cleared."
}
```

---

## ⚡ Tutorial 3: Real-Time Telemetry Streaming via MQTT

When building embedded microcontroller firmware (ESP32, STM32, Raspberry Pi Pico), MQTT is strongly recommended over HTTP because:
1. **Low Overhead:** Single persistent TCP TLS socket avoids opening and closing TLS handshakes on every reading.
2. **High Throughput:** Easily stream at 50Hz–100Hz without CPU or memory spikes.
3. **Bi-Directional:** Devices can both publish telemetry and listen for remote commands.

### MQTT Connection Parameters
* **Broker Host:** `mqtt.iimarky123.io.vn`
* **MQTTS Port (TLS):** `8883`
* **Telemetry Topic:** `channels/{channel_id}/data`
* **Username:** `d_YOUR_DEVICE_USERNAME` *(generated under Channel -> Devices)*
* **Password:** `YOUR_DEVICE_PASSWORD`

### Publishing via Mosquitto CLI
```bash
mosquitto_pub -h "mqtt.iimarky123.io.vn" -p 8883 \
  -u "d_my_sensor_node" \
  -P "my_device_secret_password" \
  -t "channels/1/data" \
  -m '{"temperature": 25.1, "humidity": 59.3}'
```

### Subscribing to Live Channel Events
```bash
mosquitto_sub -h "mqtt.iimarky123.io.vn" -p 8883 \
  -u "d_my_sensor_node" \
  -P "my_device_secret_password" \
  -t "channels/1/data" -v
```

---

## 📡 Tutorial 4: Downlink Device Remote Control & Actuation

ThingLarp supports bidirectional IoT communication. You can dispatch commands from the web/mobile app or HTTP API down to your edge devices (ESP32, Raspberry Pi, relays, motors) in real time.

### How Downlink Dispatch Works
1. You make an HTTP request to `POST /channels/{channel_id}/commands`.
2. The ThingLarp API publishes the payload to MQTT topic `channels/{channel_id}/{subtopic}` (default: `channels/{channel_id}/commands`) at QoS 1.
3. Connected devices subscribed to this topic immediately receive the JSON payload and execute the requested action.

### Dispatching via cURL
```bash
curl -X POST "https://api.iimarky123.io.vn/channels/1/commands" \
  -H "Content-Type: application/json" \
  -H "X-API-Key: tl_write_YOUR_KEY_HERE" \
  -d '{
    "payload": {
      "relay": 1,
      "state": "ON"
    },
    "subtopic": "commands"
  }'
```

### Receiving Commands on ESP32 (Arduino C++)
Make sure the provisioned device scope is set to `subscribe` or `pubsub`:
```cpp
void callback(char* topic, byte* payload, unsigned int length) {
  StaticJsonDocument<256> doc;
  deserializeJson(doc, payload, length);

  if (doc.containsKey("relay")) {
    int relayNum = doc["relay"];
    const char* state = doc["state"];
    if (strcmp(state, "ON") == 0) {
      digitalWrite(RELAY_PIN, HIGH);
    } else {
      digitalWrite(RELAY_PIN, LOW);
    }
  }
}

// In setup / reconnect logic:
client.subscribe("channels/1/commands", 1);
```

### Receiving Commands in Python
```python
import paho.mqtt.client as mqtt
import json

def on_message(client, userdata, msg):
    cmd = json.loads(msg.payload.decode())
    print(f"Received command on {msg.topic}: {cmd}")
    if cmd.get("relay") == 1 and cmd.get("state") == "ON":
        print("Actuator: Turning Relay ON!")

client = mqtt.Client()
client.tls_set()
client.username_pw_set("d_esp32_node", "YOUR_DEVICE_PASSWORD")
client.on_message = on_message
client.connect("mqtt.iimarky123.io.vn", 8883)
client.subscribe("channels/1/commands", qos=1)
client.loop_forever()
```

---

## 📥 Tutorial 5: Data Migration & CSV Import Tool

Have existing historical telemetry from ThingSpeak or another platform? ThingLarp provides an automated CSV import engine that parses historical timestamps and registers all discovered fields in TimescaleDB.

### Supported CSV Formats
1. **ThingSpeak Export Format:**
   ```csv
   created_at,entry_id,field1,field2
   2026-11-12T00:00:00Z,1,24.5,60.2
   2026-11-12T01:00:00Z,2,25.1,58.9
   ```
2. **Standard Time-Series Format:**
   ```csv
   time,temperature,humidity,lux
   2026-11-12 12:00:00,24.5,60.2,450
   2026-11-12 12:05:00,25.1,58.9,460
   ```

### Importing via cURL
```bash
curl -X POST "https://api.iimarky123.io.vn/channels/1/import" \
  -H "Content-Type: text/csv" \
  -H "X-API-Key: tl_write_YOUR_KEY_HERE" \
  --data-binary @export.csv
```

### Importing via the App UI
1. Open the Channel Dashboard.
2. Tap the top-right menu (**`⋮`**) and select **Import Data (CSV)**.
3. Click **Load Sample ThingSpeak CSV** to test or paste your exported CSV text directly.
4. Tap **Start Import** — your charts and snapshot metrics will update immediately!

---

## ❓ HTTP Status Codes & Troubleshooting

| HTTP Code | Meaning | Common Cause & Solution |
| :--- | :--- | :--- |
| **`202 Accepted`** | Success | Telemetry published to MQTT broker and ingested into TimescaleDB. |
| **`200 OK`** | Success | Historical or latest data returned successfully. |
| **`400 Bad Request`** | Invalid JSON | The payload body is not valid JSON. Ensure quotes around keys (`{"temp": 25}`). |
| **`401 Unauthorized`** | Missing Credentials | No `X-API-Key` or `Authorization` header provided. |
| **`403 Forbidden`** | Scope Mismatch | Using a `read` API key for a `POST` write operation. Generate a `write` key. |
| **`404 Not Found`** | Unknown Channel | The Channel ID does not exist or has been deleted. |
| **`503 Unavailable`** | Broker Offline | The API could not reach Mosquitto. Check broker container status. |

---

## 💡 Next Steps
* Run the Flutter app and test live charts in real time.
* Check the full [REST API Reference](../reference/api_reference.md) for user management and channel CRUD endpoints.
* Explore the [MQTT Topics & ACLs](../reference/mqtt_topics.md) documentation for topic permission rules.
