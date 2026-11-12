# Python Scripting Integration

Stream telemetry from a Raspberry Pi, edge gateway, or Linux server to ThingLarp using Python.

---

## 1. Using MQTT (`paho-mqtt`)

```bash
pip install paho-mqtt
```

```python
import time
import json
import random
import paho.mqtt.client as mqtt

BROKER_HOST = "mqtt.iimarky123.io.vn"
BROKER_PORT = 8883
CHANNEL_ID = 42

DEVICE_USER = "d_YOUR_DEVICE_USER"
DEVICE_PASS = "YOUR_DEVICE_PASSWORD"
TOPIC = f"channels/{CHANNEL_ID}/data"

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to ThingLarp Broker!")
    else:
        print(f"Connection failed, rc={rc}")

client = mqtt.Client(client_id=f"python_worker_{random.randint(1000, 9999)}")
client.username_pw_set(DEVICE_USER, DEVICE_PASS)
client.tls_set() # Enable TLS
client.on_connect = on_connect

client.connect(BROKER_HOST, BROKER_PORT, keepalive=60)
client.loop_start()

try:
    while True:
        payload = {
            "cpu_temperature": 48.2 + random.uniform(-1.5, 1.5),
            "ram_usage_pct": 34.1 + random.uniform(-0.5, 0.5),
            "disk_free_gb": 112.4
        }

        print("Publishing:", payload)
        client.publish(TOPIC, json.dumps(payload), qos=1)
        time.sleep(5)
except KeyboardInterrupt:
    client.loop_stop()
    client.disconnect()
```

---

## 2. Using HTTP REST (`requests`)

```bash
pip install requests
```

```python
import time
import requests

API_URL = "https://api.iimarky123.io.vn/channels/42/data"
API_KEY = "tl_ak_YOUR_API_KEY_HERE"

while True:
    payload = {
        "metric_a": 12.4,
        "metric_b": 98.1
    }

    res = requests.post(
        API_URL,
        headers={"X-API-Key": API_KEY},
        json=payload,
        timeout=10
    )

    print(f"Sent: {payload} | Status: {res.status_code}")
    time.sleep(10)
```
