# Hardware Provisioning & Device Code Examples

This guide details how to provision physical IoT hardware nodes (ESP32, Raspberry Pi, Arduino) and write data to ThingLarp.

---

## 1. Provisioning a Device

Before an IoT device can publish data, it must be provisioned in a channel:

=== "Via Flutter App"
    1. Open your channel dashboard.
    2. Switch to the **"Devices"** tab.
    3. Click **"Provision Device"**, enter a friendly name (e.g. `LivingRoom_ESP32`).
    4. Save the generated **Username** (`d_xxxxxxxx`) and **Password**.

=== "Via REST API"
    ```bash
    curl -X POST http://localhost:8000/channels/1/devices \
      -H "Authorization: Bearer <USER_JWT_TOKEN>" \
      -H "Content-Type: application/json" \
      -d '{"name": "Weather_Station_1"}'
    ```

    **Response:**
    ```json
    {
      "id": 1,
      "channel_id": 1,
      "name": "Weather_Station_1",
      "mqtt_username": "d_e92ab04d7c",
      "mqtt_password": "super_secret_generated_password",
      "created_at": "2026-11-12T05:00:00Z"
    }
    ```

---

## 2. ESP32 Arduino C++ Example (`PubSubClient`)

```cpp
#include <WiFi.h>
#include <PubSubClient.h>
#include <ArduinoJson.h>

const char* ssid = "YOUR_WIFI_SSID";
const char* password = "YOUR_WIFI_PASSWORD";

const char* mqtt_server = "192.168.1.100"; // Or domain name
const int mqtt_port = 1883;

// Device Credentials
const char* mqtt_user = "d_e92ab04d7c";
const char* mqtt_pass = "super_secret_generated_password";
const char* topic = "channels/1/data";

WiFiClient espClient;
PubSubClient client(espClient);

void setup_wifi() {
  delay(10);
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(500);
  }
}

void reconnect() {
  while (!client.connected()) {
    if (client.connect("ESP32_Weather_Node", mqtt_user, mqtt_pass)) {
      Serial.println("Connected to ThingLarp Broker!");
    } else {
      delay(2000);
    }
  }
}

void setup() {
  Serial.begin(115200);
  setup_wifi();
  client.setServer(mqtt_server, mqtt_port);
}

void loop() {
  if (!client.connected()) {
    reconnect();
  }
  client.loop();

  // Create Dynamic JSON Payload
  StaticJsonDocument<200> doc;
  doc["temperature"] = 24.5 + random(-10, 10) / 10.0;
  doc["humidity"] = 55.0 + random(-20, 20) / 10.0;
  doc["voltage"] = 3.71;
  doc["rssi"] = WiFi.RSSI();

  char buffer[256];
  serializeJson(doc, buffer);

  // Publish to ThingLarp
  client.publish(topic, buffer);
  Serial.print("Published: ");
  Serial.println(buffer);

  delay(2000); // Publish every 2 seconds
}
```

---

## 3. MicroPython Example (ESP32 / Raspberry Pi Pico W)

```python
import time
import ujson
import machine
from umqtt.simple import MQTTClient
import network

# 1. Connect WiFi
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
wlan.connect('YOUR_WIFI_SSID', 'YOUR_WIFI_PASSWORD')
while not wlan.isconnected():
    time.sleep(0.5)

# 2. MQTT Parameters
BROKER = '192.168.1.100'
PORT = 1883
USER = 'd_e92ab04d7c'
PASS = 'super_secret_generated_password'
TOPIC = b'channels/1/data'

client = MQTTClient('pico_node', BROKER, port=PORT, user=USER, password=PASS)
client.connect()
print("Connected to ThingLarp!")

step = 0
while True:
    step += 1
    payload = {
        "temperature": 23.4,
        "humidity": 58.2,
        "co2": 412,
        "counter": step
    }
    client.publish(TOPIC, ujson.dumps(payload))
    time.sleep(2.0)
```

---

## 4. Raspberry Pi / Python Example

```python
import time
import json
import paho.mqtt.client as mqtt

BROKER = "localhost"
PORT = 1883
USERNAME = "d_e92ab04d7c"
PASSWORD = "super_secret_generated_password"
CHANNEL_ID = 1

client = mqtt.Client(client_id="rpi_station")
client.username_pw_set(USERNAME, PASSWORD)
client.connect(BROKER, PORT, keepalive=60)

step = 0
while True:
    step += 1
    telemetry = {
        "cpu_temp": 42.1,
        "ram_usage_mb": 512,
        "disk_free_gb": 48.2,
        "seq": step
    }
    client.publish(f"channels/{CHANNEL_ID}/data", json.dumps(telemetry))
    print(f"Sent: {telemetry}")
    time.sleep(1.0)
```
