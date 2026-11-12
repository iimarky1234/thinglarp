# MicroPython Integration

This guide provides a minimal script to stream sensor telemetry to ThingLarp using **MicroPython** on an **ESP32** or **Raspberry Pi Pico W**.

---

## Required Library
Ensure `umqtt.simple` is installed:
```python
import mip
mip.install("umqtt.simple")
```

---

## Complete MicroPython Script

```python
import time
import ujson
import network
import urandom
from umqtt.simple import MQTTClient

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------
WIFI_SSID = "YOUR_WIFI_SSID"
WIFI_PASS = "YOUR_WIFI_PASSWORD"

BROKER_HOST = "mqtt.iimarky123.io.vn"
BROKER_PORT = 8883

CHANNEL_ID = 42
DEVICE_USER = "d_YOUR_DEVICE_USER"
DEVICE_PASS = "YOUR_DEVICE_PASSWORD"
TOPIC = f"channels/{CHANNEL_ID}/data"

# -----------------------------------------------------------------------------
# Connect WiFi
# -----------------------------------------------------------------------------
wlan = network.WLAN(network.STA_IF)
wlan.active(True)
wlan.connect(WIFI_SSID, WIFI_PASS)

print("Connecting to WiFi...", end="")
while not wlan.isconnected():
    time.sleep(0.5)
    print(".", end="")
print(f"\nWiFi connected: {wlan.ifconfig()[0]}")

# -----------------------------------------------------------------------------
# Connect MQTT & Publish Loop
# -----------------------------------------------------------------------------
client_id = f"pico_{urandom.getrandbits(16):04x}"
client = MQTTClient(
    client_id=client_id,
    server=BROKER_HOST,
    port=BROKER_PORT,
    user=DEVICE_USER,
    password=DEVICE_PASS,
    ssl=True,
    ssl_params={"server_hostname": BROKER_HOST}
)

client.connect()
print("Connected to ThingLarp Broker!")

while True:
    # Read hardware sensors
    temp = 24.5 + (urandom.getrandbits(8) % 30) / 10.0
    humidity = 58.0 + (urandom.getrandbits(8) % 40) / 10.0

    payload = {
        "temperature": temp,
        "humidity": humidity,
        "device_status": "online"
    }

    raw_json = ujson.dumps(payload)
    print("Publishing:", raw_json)
    client.publish(TOPIC, raw_json)

    time.sleep(5)
```
